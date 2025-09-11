# AI Thing (Previously This)

------------------------ 

Thursday
- Update Doc BYOK Free
- Update Doc for Model Selection 
- Update Doc for Prompt Cache & Output Token
- Store Selected Tools in Local Storage

Friday
- Create OAuth Workflow for MCP 
- Asana & Atlassian MCP 
- Redesgin Own Agent UI
- Update Doc for Asana & Atlassian Tools  

Weekend
- Allow OpenAI Models 
- Detect API key in BYOK b/w Anthropic and OpenAI
- Change Models based on API Key 

Later
- Get Google Review
 
September 19
- Release 1.6

September 20
- Make Ads
- Post Reddit

------------------------


Missing Features
- Get max agent from firebase 
- No Audio recording 
- Understand you and suggest things based on time and this
- No Elicitation 
- Fix "AttributeGraph: cycle detected through attribute"
- Fix Flickering Animation
- Integration Slack, Jira
- No Markdown Select
- Search History
- Old images from history are not shown 


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




