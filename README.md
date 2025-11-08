# AI Thing (Previously This)

------------------------ 

## 2.0 


8 Nov    
- Show * for active tabs in sidebar
- Toast
- Excel Not Work 
- Show file content in code block
- Show images in horizontal scroll 
- Prevent going below the screen limit 
- Selection Enabled button
- Do not select from the app 

9 Nov
- Analytics 
- Verify MCPs
- Doc & Release 2.0

10 Nov
- YC Apply

Next
- 2 hover required to open the app after closing
- Support Edit title
- Support AI Suggestions : Understand you and suggest things based on time and this

------------------------

## Missing Features

- Support Search History
- Support Image Generation 
- Support Audio  
- Support Elicitation 
- Support Markdown Select
- Support OpenAI Models 

------------------------
    
## Servers
 
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

## Release

https://chatgpt.com/g/g-p-6873dd743bb48191b8a269cab99e4c01-ai-thing/c/688ff3cc-7be8-8329-9fed-0be50ddd3485

```
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
```

------------------------




