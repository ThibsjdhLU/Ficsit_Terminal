## 2024-05-23 - Accessibility Labels for Icon Buttons
**Learning:** Icon-only buttons (like "Add" or "Toggle Checkmark") are invisible to screen readers without explicit `.accessibilityLabel`.
**Action:** Always check `Button` contents. If it's just an `Image`, add `.accessibilityLabel(Localization.translate("..."))` to describe the action.
