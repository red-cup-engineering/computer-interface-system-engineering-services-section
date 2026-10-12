---
title: Reading This Guide
aliases:
  - GAZ Guidebook
---



## Reading This Guide
- If you see text inside `{{two curly brackets}}`, you're probably supposed to replace it with text relevant to your situation.
## Use Guides
### Maintaining Your User
#### Maintaining Your Location
Your location is set in the following place(s). This isn't meant as a precise tag, but more to show where your "home" was when you were adding content:

- Within your [QuickAdd template](QuickAdd template) for adding a [personal log entry](personal log entry).
### Entering Information
#### Personal Logs
***If you don't have a template for adding personal logs, please talk to [emsenn](emsenn)***

A new [personal log entry](personal log entry) can be created by using a [QuickAdd template](QuickAdd template) (try searching for one called `Personal log entry, {{user-name}}`), or by creating a new file in `/per/{{user-name}}/log/{{DATE:YYYY-MM-DD}}` and adding the following header:

```markdown
---
type: "[personal log entry](personal log entry)"
author: "[{{Your Name}}]({{Your Name}})"
date-entered: "[{{DATE:YYYY-MM-DD}}]({{DATE:YYYY-MM-DD}})"
location:
  - {{LATITUDE}}
  - {{LONGITUDE}}
---
```

(You don't need a location, but the other three are pretty encouraged.)