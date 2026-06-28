SOULFRAME INVENTORY GUARD
=========================

![Soulframe Inventory Guard watching a healthy session](screenshot.png)

What it does
------------
Sometimes Soulframe stops saving your inventory. When that happens, anything you
pick up afterward disappears the next time you log out and back in. The game does
not tell you it is happening, so you can lose an hour of progress without knowing.

This little tool watches Soulframe's log file while you play and pops up a warning
the SECOND saving breaks, so you can log out and back in before losing more. It
also tells you the time of your last save that will actually stick.


How to use it (the easy way)
----------------------------
1. Keep all of these files together in one folder.
2. Double-click  "Watch Soulframe.bat"
3. A small text window opens that says "Watching. Saving normally."
   Leave it open and play normally. You can start it before or after the game.
4. If saving ever breaks, the window turns red, beeps, and a warning pops up.
   When that happens: LOG OUT AND BACK IN. That fixes it and starts saving again.

That's it. You don't have to type anything.

Tip: if you play in exclusive fullscreen, the pop-up may hide behind the game and
you'll only hear the beep. Borderless or windowed mode lets the warning show on top.


"Windows protected your PC" / "Are you sure you want to run this?"
-----------------------------------------------------------------
Because this file came from the internet, Windows may ask if you trust it.
- If you see "Open File - Security Warning", click  Run.
- If you see a blue "Windows protected your PC" box, click  More info  then
  Run anyway.
Some antivirus tools are cautious about any script that uses PowerShell. This tool
only READS your log file - it makes no changes to your PC, your game, or your
account, and it never connects to the internet. Both script files are plain text;
you (or a friend) can open them in Notepad and read exactly what they do.


"It can't find the log file"
----------------------------
By default it looks here:
   C:\Users\<you>\AppData\Local\Soulframe\EE.log
If your Soulframe is installed somewhere else, you can point it at the right file.
Right-click "Watch Soulframe.bat" -> Edit, and change the last line to:
   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sf-inventory-guard.ps1" -LogPath "C:\full\path\to\EE.log"


Check a session you already played
----------------------------------
Double-click  "Check Last Session.bat"  to look at your most recent session and
see whether the bug already happened (and what your last good save time was).


Files in this folder
--------------------
   Watch Soulframe.bat        <- double-click this to watch live
   Check Last Session.bat     <- double-click to check a past session
   sf-inventory-guard.ps1     <- the actual tool (plain-text, readable)
   README.txt                 <- this file


Reporting the bug to the developers
-----------------------------------
If this catches the bug for you, that log file (EE.log) is exactly what Digital
Extremes asks for. The give-away line in it is:
   "Failed to commit inventory checkpoint: No accounts matched during the mega
    account update" / HTTP 409 Conflict
Once that starts, the game stops saving until you relog.
