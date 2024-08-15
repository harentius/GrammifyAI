# GrammifyAI

An AI-driven grammar and spell checker for macOS that works everywhere and with any language.

The usage of GrammifyAI is as simple as selecting the text and pressing a shortcut (⌘ + U or custom).  
This will bring you the improvement suggestion popup and will copy the suggestion to the clipboard.

Thanks to the macOS accessibility API, GrammifyAI can work with text in any **web** or **native** application.  
Thanks to **OpenAI**, GrammifyAI also improves your writting and language style.  
<img width="600" alt="Screenshot 2024-08-14 at 20 20 12" src="https://github.com/user-attachments/assets/9155695c-49d6-44ad-ba07-71b2e4085982">

GrammifyAI uses your OpenAI keys, so no quota or limits from GrammifyAI side: use according to OpenAI billing.

## Installation
  1. Download the latest release and move it to the Applications folder on your Mac.
  2. To run the application, right-click on the GrammifyAI app name and select "Open," then allow it to open.
  3. To add application Accessibility permissions, open "System Settings" navigate to "Privacy & Security" select "Accessibility" and add GrammifyAI to the list.
  4. Add your OpenAI API key in the Settings.
  5. Select the text in any application and press ⌘ + U or your custom shortcut.

## Update
  After installing a new version you need to remove the GrammifyAI from Accessibility permissions and give them again.  
  You might need to perform step 2 from installation process again.

## Known successful use cases
I use the GrammifyAI application in *Slack*, *Chrome*, *Notion*, *Messenger*, and any standard web form.  

## Known limitations
  * It doesn't work in *Google Docs*
  * As it uses OpenAI API, suggestion on sensitive topics can differ from original meaning

## Demo
https://github.com/user-attachments/assets/6d13aa8b-1659-468a-aa44-d245dc65a4c1

## Appendix
 1. **Motivation for implementing this applications**  
I am learning German, and it is challenging.  
My thinking patterns differ from those of typical native speakers.  
I am trying to receive feedback on my writing as quickly as possible, so I have implemented a tool to check it.
There are great applications like Grammarly that do a similar job, but unfortunately, they only support English,  
and their AI capabilities can be a bit expensive and not as good as OpenAI or ChatGPT.  
I would also like to perform the check with a simple key press and minimal UI interaction.

3. Your OpenAI API key is used solely to connect with OpenAI for the purpose of GrammifyAI functionality and is not shared with anyone else.  
Feel free to review the code and build the app on your machine if you have any concerns. ;)  
It is stored locally on your device in an unencrypted manner, so use it at your own risk.  
