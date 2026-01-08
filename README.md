# GrammifyAI

**Minimalist LLM Grammar Checker for macOS that works with any application and language.**

Using GrammifyAI is as simple as selecting text and pressing a shortcut (`⌘ + U` or custom).
This triggers a popup with improvement suggestions and automatically copies the corrected text to your clipboard.

Thanks to the macOS Accessibility API, GrammifyAI works with text in any **web** or **native** application.
By leveraging **LLM integration** (e.g., OpenAI), it not only fixes grammar but also improves your writing style and tone.

<img width="500" alt="App Screenshot" src="https://github.com/user-attachments/assets/9155695c-49d6-44ad-ba07-71b2e4085982" />
<img width="295" alt="Diff View" src="https://github.com/user-attachments/assets/c9c94f08-e5d9-44d3-b095-96b616f4b87c" />

GrammifyAI utilizes your own LLM API key. There are no quotas or limits from the GrammifyAI side; usage depends entirely on your LLM API billing.

## Installation

1.  Download the latest [release](https://github.com/harentius/GrammifyAI/releases) and move it to your **Applications** folder.
2.  Right-click the GrammifyAI app and select "Open" to bypass the initial security check. Grant permission to open it if prompted.
    * *Note:* If the app is blocked, go to **System Settings > Privacy & Security** and allow the app to open.
    <img width="500" alt="open-app" src="https://github.com/user-attachments/assets/a379066d-c35e-4e4b-a55d-847f5833c396" />
3.  Grant Accessibility permissions: Open **System Settings > Privacy & Security > Accessibility** and add GrammifyAI to the list.
    <img width="500" alt="accessibility" src="https://github.com/user-attachments/assets/8d804d99-a8c5-4835-b9f9-4a2ed7a52902" />
4.  Add your API key in the GrammifyAI settings. You can use any LLM with an OpenAI-compatible API.

## Updating the App
1.  After installing a new version, you must **remove** GrammifyAI from the Accessibility permissions list and **add it again**.
2.  You may need to repeat the "Right-click Open" step from the installation process.

## Usage
1.  Select the text you want to enhance.
2.  Press `⌘ + U` (or your custom shortcut).
3.  Review the suggested correction in the diff view.
    * *Tip:* Click the input field to regain focus if needed.
4.  Press `⌘ + V` to paste the corrected text.

## Known Successful Use Cases
I use GrammifyAI daily in *Slack*, *Chrome*, *Notion*, *Messenger*, and standard web forms.

## Known Limitations
* Does not currently work in *Google Docs*.
* Since it uses an LLM, suggestions for sensitive or nuanced topics may occasionally alter the original meaning.

## Demo

https://github.com/user-attachments/assets/0ce6d724-68ee-4fa7-a468-54584888e801

## Appendix

### 1. Motivation
I am currently learning German, which I find challenging. My thinking patterns differ from those of native speakers, and I wanted a way to receive immediate feedback on my writing without friction.

I built this tool to get quick, one-shortcut corrections without needing to engage in long conversations with ChatGPT or switch windows. While tools like Grammarly are great, they primarily support English, and their AI subscriptions can be expensive compared to using your own API key with modern LLMs.

### 2. Privacy & Security
Your API key is used **solely** to connect with the specified host (default: OpenAI) to provide functionality. It is not shared with anyone else.
* **Note:** The key is stored locally on your device in an unencrypted manner. Please use it at your own risk.
* Feel free to review the code and build the app yourself if you have any security concerns! ;)