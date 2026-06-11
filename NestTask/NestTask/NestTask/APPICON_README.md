# AppIcon Setup

`Assets.xcassets/AppIcon.appiconset` is prepared as the iOS app icon slot.

When the final icon artwork is ready:

1. Export a square PNG at exactly `1024 x 1024` pixels.
2. Do not include transparency or rounded corners in the PNG.
3. Place it at:

   `NestTask/NestTask/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

4. Update `NestTask/NestTask/Assets.xcassets/AppIcon.appiconset/Contents.json` so the image entry includes:

   `"filename" : "AppIcon-1024.png"`

The Xcode target is already configured to use the `AppIcon` app icon set.
