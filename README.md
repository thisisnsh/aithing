# AI Thing (Previously This)


Missing Features
- No Audio recording 
- No Ability to Choose Tools 
- Understand you and suggest things based on time and this
- No RAG
- No Elicitation 
- No Type into Applications
- No One Click Integrations 
- No Markdown Select
- Fix "AttributeGraph: cycle detected through attribute"
- Fix Flickering Animation
- Search History


------------------------ 

- Video 1 - Introducing 
- Video 2 - Selective Context 
- Video 3 - Privacy 

Rate limit error 
high credit usage on image 

16 Satursday
- Analytics
- QA & Release
- Type anywhere 

17 Sunday
- Demo Videos

18 Monday
- 

19 Tuesday
- 

20 Wednesday
- 



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
  -o "AIThing-<version>.dmg"

rm AIThing-temp.dmg

codesign -dv --verbose=4 AIThing.app 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'

codesign --sign "Developer ID Application: Nishant Hada (983LBM5U6B)" \
  --timestamp \
  AIThing-<version>.dmg

xcrun notarytool submit "AIThing-<version>.dmg" --keychain-profile "notary-profile" --wait
xcrun stapler staple "AIThing-<version>.dmg"

codesign -dv --verbose=4 AIThing-<version>.dmg 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'
