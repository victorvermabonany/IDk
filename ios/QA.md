# Native QA matrix

Run this matrix after `Scripts/validate-ios.sh` on macOS.

## Required devices

- iPhone SE (3rd generation): compact height, keyboard, bottom CTA, tab labels
- iPhone 16 Pro: primary visual and interaction baseline
- iPhone 16 Pro Max: wide layouts and readable line lengths

## Core journey

- Fresh launch shows the welcome experience without clipping the home indicator.
- Complete Store, Household, Food, and Pantry steps using only native controls.
- Validate ZIP and budget errors; confirm focus remains understandable with VoiceOver.
- Background and relaunch during generation; confirm the same job resumes.
- Confirm Week opens with dinners, basket total, budget, remaining money, and grocery access in the initial viewport.
- Open every recipe, use large cooking text, return to Week, and open Groceries.
- Check and uncheck grocery items; the list must not reorder.
- Mark an item “I have this”; confirm the subtotal and remaining budget update.
- Open swap previews, confirm price deltas, apply a swap, and confirm Week and Groceries use the updated plan.

## Appearance and reflow

- Light appearance on all three devices.
- Dark appearance on all three devices.
- Dynamic Type: default, XXXL, Accessibility 2, and Accessibility 5.
- Display Zoom on a compact and large device.
- Portrait is the supported V1 orientation; recipe content must still be readable when the device rotates before the orientation lock settles.
- Verify no content is hidden by Dynamic Island, status bar, home indicator, keyboard, tab bar, or sheet detents.

## Accessibility

- VoiceOver traversal follows visual order on every screen.
- Week summary is announced once with dinner count, basket total, budget, and money left.
- Grocery checkoffs expose “Check” and “Uncheck”; menu actions expose “I have this” and “Add to basket.”
- Selection controls announce selected state.
- Generation stages and completed swaps announce meaningful state changes without repeated noise.
- Reduce Motion removes nonessential transition movement.
- Differentiate Without Color leaves selection, budget, errors, and completion understandable.
- All targets remain at least 44 by 44 points.

## Keyboard and input

- ZIP uses the number pad and enforces five digits.
- Budget uses the number pad and rejects values below $20.
- The keyboard never covers the active field or bottom action.
- Interactive dismissal works on multiline food and pantry fields.
- The keyboard toolbar Done action dismisses focus.

