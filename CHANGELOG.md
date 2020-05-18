## 1.5.0

* Added `Audio.liveStream(url)`
* Fixed notification image from assets on android
* Fixed android notification actions on playlist
* Added `AudioWidget`

## 1.4.7

* added `package` on assets audios (& notif images)
* all methods return Future
* open can throw an exception if the url is not found

## 1.4.6+1

* fixed android notifications actions
* refactored package, added `src/` and `package` keyword
* added player_builders

## 1.4.5

* fixed implementation of local file play on iOS

## 1.4.4

* Added notifications on android

## 1.4+3+6

* Beta fix for audio focus

## 1.4+3+5 

* Beta implementation of local file play on iOS

## 1.4.3+4

* Moved to last flutter version `>=1.12.13+hotfix.6`
* Implemented new android `FlutterPlugin` 
* Stop all players while getting a phone call
* Added `playspeed` as optional parameter on on open()

## 1.4.2+1

* Moved to android ExoPlayer
* Added `playSpeed` (beta)
* Added `forwardRewind` (beta)
* Added `seekBy`

## 1.4.0+1

* Bump gradle versions : `wrapper`=(5.4.1-all) `build:gradle`=(3.5.3)

## 1.4.0

* Added `respectSilentMode` as open optional argument
* Added `showNotification` on iOS to map with MPNowPlayingInfoCenter (default: false)
* Added `metas` on audios (title, artist, ...) for notifications
* Use new plugin build format for iOS

## 1.3.9

* Empty constructor now create a new player
* Added factory AssetsAudioPlayer.withId()
* Added `playAndForget` witch create, open, play & dispose the player on finish
* Added AssetsAudioPlayer.allPlayers() witch returns a map of all players
* Reworked the android player

## 1.3.8+1

* Added `seek` as optional parameter on `open` method

## 1.3.8

* Fully rebased the web support on html.AudioElement (instead of howler)
* Fully rebases the ios support on AvPlayer (instead of AvAudioPlayer)
* Added support for network audios with `.open(Audio.network(url))` on Android/ios/web

## 1.3.7+1

* Added `RealtimePlayingInfos` stream

## 1.3.6+1

* Added volume as optional parameter on open()

## 1.3.6

* Extracted web support to assets_audio_player_web: 1.3.6

## 1.3.5+1

* Volume does not reset anymore on looping audios

## 1.3.4

* Fixed player on Android

## 1.3.3

* Fixed build on Android & iOS

## 1.3.2

- Rewritten the web support, using now https://github.com/florent37/flutter_web_howl

## 1.3.1+2

* Upgraded RxDart dependency
* fixed lint issues
* lowerCamelCase AssetsAudioPlayer volumes consts 

## 1.3.1

* Fixed build on iOS

## 1.3.0 

* Added web support, works only on debug mode

## 1.2.8

* Added constructors 
- AssetsAudioPlayer.newPlayer
- AssetsAudioPlayer(id: "PLAYER_ID") 

to create new players and play multiples songs in parallel

the default constructor AssetsAudioPlayer() still works as usual

## 1.2.7

* Added "volume" property (listen/set)

## 1.2.6

* Added an "autoPlay" optional attribute to open methods

## 1.2.5

* Compatible with Swift 5

## 1.2.4

* Added playlist

## 1.2.3

* Added playlist (beta)

## 1.2.1

* Added looping setter/getter

## 1.2.0

* Upgraded RxDart to 0.23.1
* Fixed assets playing on iOS
* Fixed playing location on Android

## 0.0.1

* initial release.
