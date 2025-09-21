# AI Thing (Previously This)

------------------------ 

Saturday & Sunday
- Perform QA
- Update Doc BYOK Free
- Update Doc for Model Selection 
- Update Doc for Prompt Cache & Output Token
- Update Doc for Adding Global Agents   
- Release 1.6

Sunday 
- Make UI on notebook 

Sep 22
- Select text show FAB and show selected text

Sep 23
- Drag to grab image and show FAB

Sep 24
- Vertical history 

Sep 25
- Generate image and drag outside 

Sep 26
- Landing page 

Sep 27
- Edit tab title 

Sep 28
- a

Sep 29
- a

Sep 30
- a

Oct 1
- a

Oct 2
- a

Oct 3
- a

Oct 4
- a

Oct 5
- a

- select a text, and ai thing shows up to help 
- press shortcut, grab the screen, and ai thing shows up to help
- press shortcut, see ai thing, task anything, do anything

- Select a text, if text can be selected, show the icon
- Hover over the icon, color shows, click to expand into text box
- how to see history? how to expand? how to continue? 

- ctrl+sht+4 to screen grab, and show on top, below that ai thing, where the cursor was
- how to see history? how to expand? how to continue? 

- press ctrl when tab is open to show the top 10 tabs and the shortcuts to resume 
- also show the icon to close the tab while pressing command   
- settigs button right of input 

- first open landing app with instructions and login 
- ctrl+space to hide and show 

- minimize button, fabs floating everywhere upto 10 
- edit title of floating tab 

- all local storage 

- selected text is shown in the input box 
- show screen grab option to add image to the input 
- drag and drop image out of ai thing 



Usecase
- text edit
- text write
- code understand
- code debug 
- code write 
- create image 
- understand image 
- 







Later
- Wait for Google
- Create Ads
- Create Post Reddit
- Post Ads
- Post Posts


------------------------


Missing Features
- Audio commands 
- Listen computer audio 
- Live transcribe and send to AI 
- Get max agent from firebase 
- No Audio recording 
- Understand you and suggest things based on time and this
- No Elicitation 
- Fix "AttributeGraph: cycle detected through attribute"
- Fix Flickering Animation
- No Markdown Select
- Search History
- Old images from history are not shown 
- Allow OpenAI Models 
- Detect API key in BYOK b/w Anthropic and OpenAI
- Change Models based on API Key 


------------------------
    

Anthropic
<your-anthropic-api-key>

Zapier
https://mcp.zapier.com/api/mcp/mcp
<zapier-basic-auth>

GitHub
https://api.githubcopilot.com/mcp/ 
<your-github-token>    

Xcode
/usr/local/bin/xcode-npx-wrapper
-y xcodebuildmcp@latest

Apple
/Users/thisisnsh/.bun/bin/bunx
@dhravya/apple-mcp@latest

Google Sheets
https://docs.google.com/spreadsheets/d/<spreadsheet-id>


------------------------


Release
https://chatgpt.com/g/g-p-6873dd743bb48191b8a269cab99e4c01-ai-thing/c/688ff3cc-7be8-8329-9fed-0be50ddd3485

export version=<version>

spctl --assess --type execute --verbose AIThing.app 
AIThing.app: accepted
source=Notarized Developer ID

hdiutil create -volname "AIThing" \
  -srcfolder "AIThing_dmg" \
  -format UDRW \
  -fs HFS+ \
  -ov "AIThing-temp.dmg"

hdiutil attach "AIThing-temp.dmg"

open /Volumes/AIThing

hdiutil detach /Volumes/AIThing

hdiutil convert "AIThing-temp.dmg" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "AIThing-$version.dmg"

rm AIThing-temp.dmg

codesign -dv --verbose=4 AIThing.app 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'

codesign --sign "Developer ID Application: Nishant Hada (983LBM5U6B)" \
  --timestamp \
  AIThing-$version.dmg

xcrun notarytool submit "AIThing-$version.dmg" --keychain-profile "notary-profile" --wait
xcrun stapler staple "AIThing-$version.dmg"

codesign -dv --verbose=4 AIThing-$version.dmg 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'



------------------------




