# Written by FreeBSD-setup: Konsole's default profile (terminal style).
# Change it in Konsole (Settings > Configure Konsole > Profiles): Konsole
# then saves your own copy, which is used instead of this one.
[General]
Name=FreeBSD
Parent=FALLBACK/
Command=@SHELL@
Environment=TERM=xterm-256color,COLORTERM=truecolor
TerminalColumns=110
TerminalRows=30
TerminalMargin=8

[Appearance]
ColorScheme=Breeze
Font=JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Scrolling]
HistoryMode=2

[Terminal Features]
BlinkingCursorEnabled=true
