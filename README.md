# AI Thing (Previously This)

------------------------ 


Sunday
- Dynamic App Context Width
- Release 2.0.8 
- Google Server Stats
- Google Server Rate Limit


Monday
- [Morning 8am] Reddit Release
- [Evening 6pm] Email people about the new release who emailed you before

Later
- RAG 
- Token Count / Savings
- Get API Key seamlessly 
- Search Tools
- Search History
- Add notification for automation


Jan 1, 2026
- PH Release

------------------------

## Missing Features

- Support Image Generation 
- Support Audio  
- Support Elicitation 
- Support Markdown Select 
- Support AI Suggestions


## Not Important Bugs

- 2 hover required to open the app after closing
- First file drop is slow

------------------------
    
## Servers
 
Anthropic
<your-anthropic-api-key>

Zapier
https://mcp.zapier.com/api/mcp/mcp
https://mcp.zapier.com/authorize?client_id=<zapier-client-id>&redirect_uri=http://127.0.0.1:62326/callback&response_type=code&scope=profile%20email&state=F21AAA44-0643-4C90-824F-482C8FCFD27A

GitHub
https://api.githubcopilot.com/mcp/ 

Xcode
/usr/local/bin/xcode-npx-wrapper
-y xcodebuildmcp@latest

Apple
/Users/thisisnsh/.bun/bin/bunx
@dhravya/apple-mcp@latest

------------------------

## Release

https://chatgpt.com/g/g-p-6873dd743bb48191b8a269cab99e4c01-ai-thing/c/688ff3cc-7be8-8329-9fed-0be50ddd3485

```
>>> change bundle version in info.plist
>>> change bundle version in settings

export version=<version>

>>> spctl --assess --type execute --verbose AIThing.app 
>>> AIThing.app: accepted
>>> source=Notarized Developer ID

echo $version

cp AIThing.app AIThing_dmg

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

mv AIThing-$version.dmg ../Sparkles/  

../Sparkle-2.8.1/bin/generate_appcast ../Sparkles

cd ../Sparkles

scp -i ~/.ssh/id_rsa * root@159.89.183.84:/var/www/html

ssh -i ~/.ssh/id_rsa root@159.89.183.84

cd /var/www/html

```

------------------------
