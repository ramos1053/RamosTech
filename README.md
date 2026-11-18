# RamosTech

This is where I put projects that come out of poking at macOS and Windows: scripting, automation, the occasional enterprise workflow idea. Some of it ends up genuinely useful. A lot of it is me trying to find the edges of what's possible, or figuring out why something doesn't work the way the docs say it should.

## About me

I spend most of my time in the Apple ecosystem, working on macOS fleet automation, device management and secure workflow design. When I write documentation I try to write it for the person who has to use the thing, not for the person who already understands it.

## Projects in this repo

| Project | Platform | What it does |
|---------|----------|--------------|
| [GottaGo](GottaGo/README.md) | iOS | Finds public restrooms worldwide. Pulls live data from several APIs and shows it on a map with favorites and walking routes. |
| [Nimbus-Swift](Nimbus-Swift/README.md) | macOS | A Swift rewrite of Nimbus, a Cumulus server management tool that first appeared in 2003. It adds real-time server monitoring. |
| [PIP](PIP/README.md) | macOS | A text editor for bash scripting and other programming work, written in Swift and built to stay fast on large files. |
| [Tabby](Tabby/README.md) | macOS | A menu bar app that shows every open tab in Chrome and Edge in one grid, so you can stop hunting through two browsers. |
| [Time Machine Manager](Time%20Machine%20Manager/README.md) | macOS | Lists, inspects and deletes Time Machine local snapshots without typing `tmutil` by hand. |

## Projects with their own repos

| Project | Platform | What it does |
|---------|----------|--------------|
| [Snipster](https://github.com/ramos1053/Snipster) | macOS | A menu bar snippet manager with keyboard triggers, fill-in templates and a quick-access window you open with a hotkey. |
| [Snipster for Windows](https://github.com/ramos1053/Snipster-Windows) | Windows | The same idea as a Windows tray app, written from scratch rather than ported line by line. |
| [Restless](https://github.com/ramos1053/Restless) | macOS | Keeps your Mac awake and stops the screen from locking. It can also keep a chosen app active in the background. |
| [MPP Viewer](https://github.com/ramos1053/MPP-Viewer-Mac) | macOS | Opens and edits Microsoft Project files, with Gantt, timeline, network, calendar and resource views. |
| [NetDrive Tray](https://github.com/ramos1053/NetDrive-Tray) | Windows | Maps network drives from the system tray using a smartcard, a password or your current Windows login. |

## Stack

Most of the macOS and iOS work is Swift, and the scripts are Bash. NetDrive Tray is C# and PowerShell, and it builds on a Windows PC.

Each project is MIT licensed.

If something here saves you time, great. If not, it might at least save you from a dead end I already ran into.
