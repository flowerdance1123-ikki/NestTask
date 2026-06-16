'use strict';

// ══ 定数 ══════════════════════════════════════════════════════
const DEFAULT_THERAPIST = '野間 一輝';
const DEFAULT_NOTES = 'いつもご理解ご協力ありがとうございます。ご本人様が現状通り変わらずお元気に過ごせるよう、引き続き施術に取り組んでまいります。';

const TEMPLATE_TYPE_ALIASES = {
  bodymap: 'bodymap', '人体図': 'bodymap', '身体図': 'bodymap',
  photo: 'photo', '写真': 'photo',
  qr: 'qr', '動画': 'qr', '動画qr': 'qr', '動画QR': 'qr',
};

const TYPE_LABELS = {
  bodymap: '人体図タイプ',
  photo: '写真タイプ',
  qr: '動画QRタイプ',
};

const FORM_KEYS = [
  'patient_name', 'therapist_name', 'created_date',
  'body_status', 'recent_state', 'notes', 'shared_points',
  'photo_1_caption', 'photo_2_caption',
  'main_title', 'main_url', 'sub_title_1', 'sub_url_1',
];

const STEP_ORDER = ['step1', 'step2', 'step3a', 'step3b', 'stepDone'];

// ══ 状態 ══════════════════════════════════════════════════════
const state = {
  currentStep: 'step1',
  selectedType: null,
};

// ══ DOM参照 ═══════════════════════════════════════════════════
const form         = document.getElementById('mainForm');
const btnBack      = document.getElementById('btnBack');
const btnNext      = document.getElementById('btnNext');
const loading      = document.getElementById('loading');
const loadingMsg   = document.getElementById('loadingMsg');
const jsonInput    = document.getElementById('jsonInput');
const applyJsonBtn = document.getElementById('applyJsonBtn');
const clearJsonBtn = document.getElementById('clearJsonBtn');
const jsonError    = document.getElementById('jsonError');
const jsonInfo     = document.getElementById('jsonInfo');
const confirmContent = document.getElementById('confirmContent');
const btnDecide    = document.getElementById('btnDecide');
const btnAnother   = document.getElementById('btnAnother');
const createError  = document.getElementById('createError');

// ══ ユーティリティ ════════════════════════════════════════════

function todayJa() {
  const d = new Date();
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}

// ══ 個人情報チェック ══════════════════════════════════════════

function checkPersonalInfo(text) {
  const hits = [];
  if (/\d{2,4}[-−ー]\d{2,4}[-−ー]\d{4}/.test(text)) hits.push('電話番号');
  if (/(東京都|大阪府|京都府|北海道|[^\s\d]{2,3}[都道府県])/.test(text)) hits.push('都道府県');
  if (/[0-9０-９]+丁目|[0-9０-９]+番地/.test(text)) hits.push('住所（番地）');
  if (/(病院|クリニック|医院|診療所|薬局|老人ホーム|デイサービス|グループホーム|訪問看護|訪問介護)/.test(text)) hits.push('施設名');
  if (/(患者名|ご利用者|利用者名|氏名|お名前)\s*[：:]/.test(text)) hits.push('患者名ラベル');
  if (/[^\s\d、。]{2,5}(?:様|さん)/.test(text)) hits.push('氏名（様・さん）');
  return hits;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function val(id) {
  return (document.getElementById(id)?.value || '').trim();
}

// ══ ローディング ══════════════════════════════════════════════

function showLoading(msg) {
  loadingMsg.textContent = msg || '処理中…';
  loading.style.display = 'flex';
}

function hideLoading() {
  loading.style.display = 'none';
}

// ══ ステップ切り替え ══════════════════════════════════════════

function showStep(stepId) {
  STEP_ORDER.forEach(id => {
    const el = document.getElementById(id);
    el.classList.toggle('active', id === stepId);
  });
  state.currentStep = stepId;
  updateFooter();
  updateStepIndicator();
}

function updateFooter() {
  const s = state.currentStep;

  // 戻るボタン：STEP1では非表示
  btnBack.classList.toggle('hidden', s === 'step1');

  // 次へボタン：step3b と完了画面では非表示
  const hideNext = (s === 'step3b' || s === 'stepDone');
  btnNext.classList.toggle('hidden', hideNext);

  // 次へボタンのラベル
  const labels = {
    step1:  '次へ（テンプレートを選ぶ）→',
    step2:  '次へ（内容を入力する）→',
    step3a: '内容を確認する →',
  };
  if (!hideNext) btnNext.textContent = labels[s] || '次へ →';

  // フッターのSTEPラベル
  const stepLabels = {
    step1: 'STEP 1 / 3',
    step2: 'STEP 2 / 3',
    step3a: 'STEP 3 / 3',
    step3b: 'STEP 3 / 3',
    stepDone: '完了',
  };
  document.getElementById('footerStepLabel').textContent = stepLabels[s] || '';
}

function updateStepIndicator() {
  const s = state.currentStep;
  const stepNum = { step1: 1, step2: 2, step3a: 3, step3b: 3, stepDone: 4 }[s] || 1;

  document.querySelectorAll('.step-dot').forEach((dot, i) => {
    const n = i + 1;
    dot.classList.remove('active', 'done');
    if (n < stepNum) dot.classList.add('done');
    else if (n === stepNum) dot.classList.add('active');
  });

  document.querySelectorAll('.step-line').forEach((line, i) => {
    line.classList.toggle('done', i + 1 < stepNum);
  });
}

// ══ ナビゲーション ════════════════════════════════════════════

btnNext.addEventListener('click', async () => {
  const s = state.currentStep;
  if (s === 'step1')  await goStep1to2();
  else if (s === 'step2')  goStep2to3a();
  else if (s === 'step3a') goStep3ato3b();
});

btnBack.addEventListener('click', () => {
  const s = state.currentStep;
  if (s === 'step2')  showStep('step1');
  else if (s === 'step3a') showStep('step2');
  else if (s === 'step3b') showStep('step3a');
});

// ── STEP1 → STEP2 ──────────────────────────────────────────

async function goStep1to2() {
  const reportText = document.getElementById('reportInput').value.trim();
  const rawJson    = jsonInput.value.trim();

  // ── 個人情報チェック（日報テキストがある場合のみ）
  if (reportText) {
    const hits = checkPersonalInfo(reportText);
    if (hits.length > 0) {
      const ok = confirm(`個人情報が含まれている可能性があります（${hits.join('、')}）。\n外部APIに送信されますが、このまま続けますか？`);
      if (!ok) return;
    }
  }

  // ── ケース1：JSONが直接入力されている → 従来通り反映してSTEP2へ
  if (rawJson) {
    const parsed = extractJson(rawJson);
    if (parsed) {
      const data = Array.isArray(parsed) ? parsed[0] : parsed;
      if (data && typeof data === 'object') applyJsonToForm(data);
    }
    showLoading('読み取っています…');
    setTimeout(() => { hideLoading(); showStep('step2'); }, 800);
    return;
  }

  // ── ケース2：日報テキストがある → Gemini APIで生成
  if (reportText) {
    showLoading('AIが日報を読み取っています…');
    try {
      const resp = await fetch('/api/generate_json', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ report_text: reportText }),
      });
      const json = await resp.json();

      if (!resp.ok) {
        hideLoading();
        alert(`AIの読み取りに失敗しました。\n${json.detail || 'もう一度試してください。'}`);
        return;
      }

      if (json.ok && json.data) {
        applyJsonToForm(json.data);
      }

    } catch (err) {
      hideLoading();
      alert(`通信エラーが発生しました。\n${err.message}`);
      return;
    }
    hideLoading();
    showStep('step2');
    return;
  }

  // ── ケース3：何も入力されていない → そのままSTEP2へ（手動入力組）
  showLoading('読み取っています…');
  setTimeout(() => { hideLoading(); showStep('step2'); }, 500);
}

// ── STEP2 → STEP3a ─────────────────────────────────────────

function goStep2to3a() {
  if (!state.selectedType) {
    document.getElementById('typeError').style.display = '';
    return;
  }
  document.getElementById('typeError').style.display = 'none';
  applyTypeToStep3a(state.selectedType);
  showStep('step3a');
}

// テンプレートタイプに応じてSTEP3aのセクション表示を切り替える
function applyTypeToStep3a(type) {
  const notes = document.getElementById('section_notes');
  const photo = document.getElementById('section_photo');
  const qr    = document.getElementById('section_qr');

  notes.style.display = (type === 'bodymap' || type === 'photo') ? 'grid' : 'none';
  photo.style.display = (type === 'photo') ? 'block' : 'none';
  qr.style.display    = (type === 'qr')    ? 'block' : 'none';

  // デフォルト値のセット（空欄の場合のみ）
  if (!document.getElementById('therapist_name').value) {
    document.getElementById('therapist_name').value = DEFAULT_THERAPIST;
  }
  if (!document.getElementById('created_date').value) {
    document.getElementById('created_date').value = todayJa();
  }
  if ((type === 'bodymap' || type === 'photo') && !document.getElementById('notes').value) {
    document.getElementById('notes').value = DEFAULT_NOTES;
  }
}

// ── STEP3a → STEP3b ────────────────────────────────────────

function goStep3ato3b() {
  if (!validateForm()) {
    const firstInvalid = document.querySelector('#step3a .invalid');
    if (firstInvalid) firstInvalid.focus();
    return;
  }
  confirmContent.innerHTML = buildConfirmContent();
  showStep('step3b');
}

// ══ テンプレートカード選択 ════════════════════════════════════

document.querySelectorAll('.template-card').forEach(card => {
  card.addEventListener('click', () => {
    document.querySelectorAll('.template-card').forEach(c => c.classList.remove('selected'));
    card.classList.add('selected');
    const radio = card.querySelector('input[type=radio]');
    radio.checked = true;
    state.selectedType = radio.value;
    document.getElementById('typeError').style.display = 'none';
  });
});

// ══ バリデーション ════════════════════════════════════════════

function setInvalid(id, show) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.toggle('invalid', show);
  const errP = el.closest('.field')?.querySelector('.field-error');
  if (errP) errP.style.display = show ? '' : 'none';
}

function validateForm() {
  let ok = true;
  const type = state.selectedType;

  const hasName = !!val('patient_name');
  setInvalid('patient_name', !hasName);
  if (!hasName) ok = false;

  const hasBody = !!val('body_status');
  setInvalid('body_status', !hasBody);
  if (!hasBody) ok = false;

  const hasRecent = !!val('recent_state');
  setInvalid('recent_state', !hasRecent);
  if (!hasRecent) ok = false;

  if (type === 'qr') {
    const hasUrl = !!val('main_url');
    setInvalid('main_url', !hasUrl);
    if (!hasUrl) ok = false;
  } else {
    setInvalid('main_url', false);
  }

  return ok;
}

// 入力時にエラーを解除
['patient_name', 'body_status', 'recent_state', 'main_url'].forEach(id => {
  const el = document.getElementById(id);
  if (el) el.addEventListener('input', () => setInvalid(id, false));
});

// ══ 確認コンテンツ構築 ════════════════════════════════════════

function row(label, value) {
  const isEmpty = !value;
  const cls = isEmpty ? 'confirm-value empty' : 'confirm-value';
  const display = isEmpty ? '（未入力）' : value;
  return `<div class="confirm-row">
    <div class="confirm-label">${escapeHtml(label)}</div>
    <div class="${cls}">${escapeHtml(display)}</div>
  </div>`;
}

function buildConfirmContent() {
  const type = state.selectedType;
  let html = '';

  html += `<div class="confirm-row">
    <div class="confirm-label">シートの種類</div>
    <div class="confirm-value type-badge">${escapeHtml(TYPE_LABELS[type] || type)}</div>
  </div>`;

  html += row('患者名',           val('patient_name'));
  html += row('担当施術者名',     val('therapist_name'));
  html += row('作成日',           val('created_date'));
  html += row('身体状況・治療目的', val('body_status'));
  html += row('最近のご様子',     val('recent_state'));

  if (type === 'bodymap' || type === 'photo') {
    html += row('備考',       val('notes'));
    html += row('共有ポイント', val('shared_points'));
  }

  if (type === 'photo') {
    const p1 = document.getElementById('photo_1');
    const p2 = document.getElementById('photo_2');
    html += row('写真1',           p1?.files?.[0]?.name || '');
    html += row('写真1キャプション', val('photo_1_caption'));
    html += row('写真2',           p2?.files?.[0]?.name || '');
    html += row('写真2キャプション', val('photo_2_caption'));
  }

  if (type === 'qr') {
    html += row('メイン動画タイトル', val('main_title'));
    html += row('メイン動画URL',     val('main_url'));
    html += row('サブ動画タイトル',   val('sub_title_1'));
    html += row('サブ動画URL',       val('sub_url_1'));
  }

  // 送付書類セット
  const hasCoverLetter = document.getElementById('create_cover_letter').checked;
  const surveyVal = document.querySelector('input[name="survey_type"]:checked')?.value || 'none';
  const surveyLabelMap = { none: '付けない', first: '初回用', followup: '2回目以降用' };

  if (hasCoverLetter || surveyVal !== 'none') {
    html += `<div class="confirm-row">
      <div class="confirm-label" style="grid-column:1/-1;background:#f0f9ff;color:#2b6cb0;font-weight:700;">
        送付書類セット
      </div>
    </div>`;
    if (hasCoverLetter) {
      const clName = val('cover_letter_therapist') || val('therapist_name') || DEFAULT_THERAPIST;
      html += row('送付状',         '作成する');
      html += row('送付状 担当者名', clName);
    } else {
      html += row('送付状', '作成しない');
    }
    html += row('アンケート', surveyLabelMap[surveyVal] || surveyVal);
  }

  return html;
}

// ══ 「この内容で決定」ボタン ══════════════════════════════════

btnDecide.addEventListener('click', async () => {
  createError.style.display = 'none';
  showLoading('作成中です…');

  try {
    const data = new FormData(form);

    const resp = await fetch('/create', { method: 'POST', body: data });
    const json = await resp.json();

    if (!resp.ok) {
      throw new Error(json.detail || 'エラーが発生しました。');
    }

    // PPTXを開くボタン（pywebviewはa[download]非対応のためopen_fileで開く）
    const link = document.getElementById('downloadLink');
    const pptxFilename = json.filename;
    link.onclick = (e) => {
      e.preventDefault();
      openFile(pptxFilename);
    };

    // PDFを開くボタン群
    const pdfArea = document.getElementById('pdfDownloadArea');
    if (json.pdf_files && json.pdf_files.length > 0) {
      pdfArea.innerHTML = json.pdf_files.map(f => {
        const safeName = escapeHtml(f.filename).replace(/'/g, '&#39;');
        return `<button type="button" class="btn-download-pdf"
            onclick="openFile('${safeName}')">
           📄 ${escapeHtml(f.label)}を開く
         </button>`;
      }).join('');
      pdfArea.style.display = '';
    } else {
      pdfArea.style.display = 'none';
    }

    // 警告
    const warningBox = document.getElementById('warningBox');
    if (json.warnings && json.warnings.length > 0) {
      warningBox.innerHTML = '<strong>注意</strong><ul>' +
        json.warnings.map(w => `<li>${escapeHtml(w)}</li>`).join('') + '</ul>';
      warningBox.style.display = '';
    } else {
      warningBox.style.display = 'none';
    }

    hideLoading();
    showStep('stepDone');

  } catch (err) {
    hideLoading();
    createError.textContent = `エラー: ${err.message}`;
    createError.style.display = '';
  }
});

// ══ もう一枚作る ══════════════════════════════════════════════

btnAnother.addEventListener('click', () => {
  resetAll();
  showStep('step1');
});

function resetAll() {
  form.reset();
  state.selectedType = null;

  // テンプレートカードの選択状態をリセット
  document.querySelectorAll('.template-card').forEach(c => c.classList.remove('selected'));

  // セクション非表示
  ['section_notes', 'section_photo', 'section_qr'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = 'none';
  });

  // エラー表示リセット
  ['patient_name', 'body_status', 'recent_state', 'main_url'].forEach(id => setInvalid(id, false));
  document.getElementById('typeError').style.display = 'none';
  createError.style.display  = 'none';
  jsonError.style.display    = 'none';
  jsonInfo.style.display     = 'none';

  // 送付書類セットリセット
  document.getElementById('cover_letter_fields').style.display = 'none';

  // 写真プレビューリセット
  ['preview1', 'preview2'].forEach(id => {
    const el = document.getElementById(id);
    if (el) { el.src = ''; el.style.display = 'none'; }
  });
  ['hint1', 'hint2'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.style.display = '';
  });
}

// ══ JSON処理（既存ロジックをそのまま移植） ═══════════════════

function extractJson(raw) {
  let text = raw.replace(/```json\s*/gi, '').replace(/```\s*/g, '');
  for (let i = 0; i < text.length; i++) {
    if (text[i] === '{' || text[i] === '[') {
      const close = text[i] === '{' ? '}' : ']';
      const last = text.lastIndexOf(close);
      if (last <= i) continue;
      try { return JSON.parse(text.slice(i, last + 1)); } catch (_) { continue; }
    }
  }
  return null;
}

function normalizeTemplateType(raw) {
  if (!raw) return null;
  const key = String(raw).trim();
  return TEMPLATE_TYPE_ALIASES[key] || TEMPLATE_TYPE_ALIASES[key.toLowerCase()] || null;
}

function applyJsonToForm(data) {
  const ignored = [];

  // template_type → カード選択に反映
  const rawType = data['template_type'];
  if (rawType !== undefined) {
    const type = normalizeTemplateType(rawType);
    if (type) {
      document.querySelectorAll('.template-card').forEach(card => {
        const radio = card.querySelector('input[type=radio]');
        const matched = (radio.value === type);
        card.classList.toggle('selected', matched);
        radio.checked = matched;
      });
      state.selectedType = type;
      document.getElementById('typeError').style.display = 'none';
    } else {
      ignored.push(`template_type（"${rawType}"は未対応）`);
    }
  }

  // テキスト項目
  FORM_KEYS.forEach(key => {
    if (!(key in data)) return;
    const el = document.getElementById(key);
    if (!el) { ignored.push(key); return; }

    // 患者名は常に空欄のまま（手入力必須）。AIの推測値は使わない
    if (key === 'patient_name') return;

    let value = (data[key] !== null && data[key] !== undefined) ? String(data[key]) : '';

    if (key === 'therapist_name' && value === '') value = DEFAULT_THERAPIST;
    if (key === 'created_date'   && value === '') value = todayJa();
    if (key === 'notes' && value === '') {
      const t = state.selectedType;
      if (t === 'bodymap' || t === 'photo') value = DEFAULT_NOTES;
    }

    el.value = value;
    setInvalid(key, false);
  });

  // 未対応キーを記録
  Object.keys(data).forEach(key => {
    if (key === 'template_type') return;
    if (!FORM_KEYS.includes(key)) ignored.push(key);
  });

  return ignored;
}

// JSON反映ボタン
applyJsonBtn.addEventListener('click', () => {
  jsonError.style.display = 'none';
  jsonInfo.style.display  = 'none';

  const raw = jsonInput.value.trim();
  if (!raw) {
    jsonError.textContent = '貼り付け欄が空です。JSONを貼り付けてください。';
    jsonError.style.display = '';
    return;
  }

  const parsed = extractJson(raw);
  if (!parsed) {
    jsonError.textContent = 'JSONとして読み取れませんでした。GemのJSON出力を貼り付けてください。';
    jsonError.style.display = '';
    return;
  }

  const data = Array.isArray(parsed) ? parsed[0] : parsed;
  if (!data || typeof data !== 'object') {
    jsonError.textContent = 'JSONの形式が正しくありません。';
    jsonError.style.display = '';
    return;
  }

  const ignored = applyJsonToForm(data);
  let msg = 'フォームに反映しました。STEP2でテンプレートを確認・選択してから次へ進んでください。';
  if (ignored.length > 0) msg += `\n（無視した項目: ${ignored.join('、')}）`;
  jsonInfo.textContent = msg;
  jsonInfo.style.display = '';
});

// JSONクリアボタン
clearJsonBtn.addEventListener('click', () => {
  jsonInput.value = '';
  jsonError.style.display = 'none';
  jsonInfo.style.display  = 'none';
});

// ══ 写真ドロップゾーン（既存ロジックをそのまま移植） ══════════

function setupPhotoDropzone(inputId, previewId, hintId) {
  const input   = document.getElementById(inputId);
  const preview = document.getElementById(previewId);
  const hint    = document.getElementById(hintId);
  const drop    = input.closest('.photo-drop');

  function showPreview(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = e => {
      preview.src = e.target.result;
      preview.style.display = 'block';
      hint.style.display = 'none';
    };
    reader.readAsDataURL(file);
  }

  input.addEventListener('change', () => showPreview(input.files[0]));
  drop.addEventListener('dragover', e => { e.preventDefault(); drop.classList.add('dragover'); });
  drop.addEventListener('dragleave', () => drop.classList.remove('dragover'));
  drop.addEventListener('drop', e => {
    e.preventDefault();
    drop.classList.remove('dragover');
    const file = e.dataTransfer.files[0];
    if (file) {
      const dt = new DataTransfer();
      dt.items.add(file);
      input.files = dt.files;
      showPreview(file);
    }
  });
}

setupPhotoDropzone('photo_1', 'preview1', 'hint1');
setupPhotoDropzone('photo_2', 'preview2', 'hint2');

// ══ 送付書類セット ════════════════════════════════════════════

document.getElementById('create_cover_letter').addEventListener('change', function () {
  document.getElementById('cover_letter_fields').style.display = this.checked ? '' : 'none';
});

document.getElementById('therapist_name').addEventListener('input', function () {
  const cl = document.getElementById('cover_letter_therapist');
  cl.placeholder = this.value
    ? `担当者名（空欄の場合は「${this.value}」を使用）`
    : '担当者名（空欄=施術者名を使用）';
});

// ══ ファイル・フォルダを開く ══════════════════════════════════

async function openOutputFolder() {
  try {
    await fetch('/open_output_folder', { method: 'POST' });
  } catch (_) { /* 無視 */ }
}

// pywebviewはa[download]非対応のため、サーバー経由でmacOS openコマンドを使う
async function openFile(filename) {
  try {
    const resp = await fetch(`/open_file/${encodeURIComponent(filename)}`, { method: 'POST' });
    if (!resp.ok) {
      const json = await resp.json().catch(() => ({}));
      console.error('openFile error:', json.detail || resp.status);
    }
  } catch (err) {
    console.error('openFile fetch error:', err);
  }
}

// ══ STEP1 リアルタイム個人情報検出 ═══════════════════════════

document.getElementById('reportInput').addEventListener('input', function () {
  const hits = checkPersonalInfo(this.value);
  const warn = document.getElementById('privacyWarn');
  if (hits.length > 0) {
    warn.textContent = '⚠️ 個人情報が含まれている可能性があります：' + hits.join('、');
    warn.style.display = '';
  } else {
    warn.style.display = 'none';
  }
});

// ══ 初期化 ════════════════════════════════════════════════════
showStep('step1');
