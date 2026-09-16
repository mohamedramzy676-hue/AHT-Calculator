# AHT Pulse — Call Center Performance Tracker

Flutter app for call-center agents to log handling times, calculate AHT automatically, and track progress toward daily and monthly AHT targets.

## Planned MVP
- Android and iOS
- Target AHT setup
- Add calls in minutes and seconds
- Live AHT, call count, and total handling time
- Daily target rescue calculator
- Monthly weighted AHT forecast
- History and settings
- Offline-first storage
- App-open ad only; no ads inside the app

## Core calculation
AHT = total handling seconds / number of calls.

Monthly AHT is calculated from total monthly handling seconds divided by total monthly calls, not by averaging daily AHT values.
