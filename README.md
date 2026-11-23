# NutriCheck

An iOS app that estimates the nutrition of any food or drink from a photo and tracks your daily calories.

Take a picture of a plate of home-cooked food, a fast-food meal, a coffee, a packaged snack or its nutrition label. NutriCheck sends it to OpenAI's vision model and returns:

- Calories, protein, carbs and fat, with a servings control (½×, 1×, 2×, or a whole pack)
- A component-by-component breakdown, e.g. rice, dal, roti, oil
- A full Nutrition Facts panel with % Daily Value: fiber, sugars, added sugar, saturated and trans fat, cholesterol, sodium, potassium, calcium, iron, and vitamins A, C and D
- Caffeine and alcohol for drinks
- Ingredients, allergens and dietary tags (vegetarian, high-protein, etc.)
- Health score (1–10), processing level, glycemic impact, and practical tips
- **Refine**: correct the AI ("it was 3 rotis, cooked in ghee") and it recalculates
- **Describe it**: type what you ate instead of taking a photo

Tracking: a daily calorie ring and macro goals, meals grouped as breakfast, lunch, dinner and snacks, exercise logging (calories burned are added to what's left), a 7/30-day history chart, macro averages, "log again", and a goal calculator (Mifflin–St Jeor).

**Assistant tab**: a chat that sees your food log, exercise, goals and weight. Ask "how many calories do I have left?", "what can I eat for dinner?" or "I walked 40 minutes, how much did I burn?". It estimates calories burned from your weight using MET values. It can also offer one-tap actions (log a workout, update goals, update weight), and nothing is saved until you tap.

## Run it

1. Open `NutriCheck.xcodeproj` in Xcode (26 or later).
2. Select the **NutriCheck** target → *Signing & Capabilities* → choose your Team, and change the bundle ID (`com.g96b4yb43p.nutricheck`) to your own.
3. Add your OpenAI key: copy `Secrets.example.plist` to `NutriCheck/Secrets.plist` and paste the key. It's read on first launch and saved to the Keychain. This file is git-ignored. Or skip this and paste a key in **Settings** instead.
4. Run on your iPhone. The camera doesn't work in the Simulator; use the photo library there.

With a free Apple ID (Personal Team), apps installed on a device expire after 7 days. Run from Xcode again to reinstall; your data is kept.

Requires iOS 17+. No third-party dependencies.

## AI model

Settings lets you pick **GPT-5.6 Sol**, the default and most accurate option, or **GPT-5.6 Luna**, which is cheaper and faster. You can also enter any OpenAI model ID that accepts images and supports Structured Outputs.

Requests use the Responses API with a strict JSON schema (`Services/NutritionSchema.swift`) and `store: false`. The prompt lives in `NutritionPrompts.system`.

## Project layout

```
NutriCheck/
  App/            App entry, tab bar, DEBUG sample data & launch args
  Models/         NutritionAnalysis (AI result), FoodEntry (SwiftData), goals, settings
  Services/       OpenAIService, food & assistant schemas/prompts, assistant context, Keychain, images
  Views/
    Today/        Daily dashboard, week strip, meal sections, exercise
    Assistant/    Chat with one-tap actions
    Scan/         Camera/library/describe → analyzing → review & log
    Detail/       Full nutrition breakdown, logged entry editor
    History/      Charts and averages
    Settings/     API key, model, goals, goal calculator
```

## Before shipping to the App Store

Right now each user brings their own API key, which is fine for personal use. A public release should not ship an OpenAI key inside the app. Instead, put a small backend in front of OpenAI that holds the key, authenticates users and rate-limits requests, and point `OpenAIService` at it.

## Debug launch arguments

In DEBUG builds, set these under *Edit Scheme → Run → Arguments*:

- `-seedSampleData`: fills the last week with sample meals (replaces existing entries)
- `-initialTab 0|1|2|3`: opens Today, Assistant, History or Settings
- `-showSampleResult`: opens a sample scan result
- `-chatPrompt "text"`: sends a message to the Assistant on launch
- `-resetAllData`: deletes all logs and chats

## License

[MIT](LICENSE) © 2026 Siddharth Lama
