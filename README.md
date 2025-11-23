# AI Thing (Previously This)

------------------------ 

## 2.0 


Saturday
- Release
- Record demo video
    - ====> ai thing is an ai right-hand to notch up your workflows 
    - ====> literally because it is a notch that sits near your right hand 
    
    - you can connect to many agents at once 
    - either from this list, or add your own agents 
    - and perform one of tasks like ...   
    
    - create an event to meet jess at 5pm tomorrow
    
    - or create recurring automations like 
    
    - summaize all unread emails every day 9am 
    - for this demo, explain any random concept in ai to a kid every 5mins  
    
    - till we wait for this automation to kick in 
    - we can ask it to 
    
    - analyse the sales in this sheet
    - using the app context it knows what this is and you can view what this is 
    - no continuous screen grabs, and if the screen is used as context, you can review before it leaves your system 
        
    - while it does that ... in parallel we can ... 
    
    - get all bug reports from today and create github issues in this repo
    - and... give me speaking points from this paper for the class 
    
    - all the conversations, tokens and secrets are stored locally on your system 
    - all the files, images used in the conversation are encoded and used just during the conversation 
    
    - we could do more complex things like ... 
    
    - summarize the responses in this form    
    - create the doc with the summary 
    - send a thank you email to whoever responded

    - (coming back to analysis ...) 
    - send email to jess@aithing.dev about the analysis
    - create the tasks to meet jess and discuss about analysis
         
    - (well this is the only ai thing you need for your work)    


-------------

- hover over ai thing
- click on the plus icon 

- what is income statement?
- modify that from millions to billions
- DO NOT WAITTTTTT

- [minimize using keyboard shortcut]

- [new tab] summaize unread emails
- @aithing create automation to do that daily at 9am 
- [show automation]
- [modify title]

- put the summary of the change in a google doc and email the doc to help@aithing.dev to review
- DO NOT WAITTTTTT

- [show doc] 
- [show email]

- give me 5 talking points
- [grab a photo on page 3] explain this 

- [enable selection] convert this code from swift to python  

- [show ai models]
- [show ai agents] 







    
Sunday
- PH Pre-Release for Wednesday
- Promotion graphics 
    - summarize unread emails daily 9am
    - give me talking points for these papers
    - create draft email for all emails from clients about recent outage
    - remove all junk emails daily 12pm
    - summarize all feedback emails every friday 9am
    - analyse the sales in this sheet 
    - what is forest tree search?


Wednesday 
- PH Release
- Promote 2.0 on Reddit  
- Email people about the new release who emailed you before


Tuesday
- Google Server Stats
- Persist MCP Servers
- Speed up reconnection of MCP Servers
- Chat not updated

------------------------


## Missing Features

- Support Image Generation 
- Support Audio  
- Support Search History
- Support Elicitation 
- Support Markdown Select
- Support OpenAI Models 
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
<zapier-basic-auth>
https://mcp.zapier.com/authorize?client_id=<zapier-client-id>&redirect_uri=http://127.0.0.1:62326/callback&response_type=code&scope=profile%20email&state=F21AAA44-0643-4C90-824F-482C8FCFD27A

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
change bundle version in info.plist
change bundle version in settings
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


## Useful 

scp -i ~/.ssh/id_rsa logo.png root@159.89.183.84:/var/www/html
ssh -i ~/.ssh/id_rsa.pub  root@159.89.183.84

