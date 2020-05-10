import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import 'model/MyAudio.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

class SongsSelector extends StatelessWidget {
  final Playing playing;
  final List<MyAudio> audios;
  final Function(MyAudio) onSelected;
  final Function(List<MyAudio>) onPlaylistSelected;

  SongsSelector(
      {@required this.playing,
      @required this.audios,
      @required this.onSelected,
      @required this.onPlaylistSelected});

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      boxShape:
          NeumorphicBoxShape.roundRect(BorderRadius.circular(9)),
      style: NeumorphicStyle(
        depth: -8,
      ),
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(8),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemBuilder: (context, position) {
                final item = this.audios[position];
                final isPlaying =
                    item.audio.path == this.playing?.audio?.assetAudioPath;
                return Neumorphic(
                  margin: EdgeInsets.all(4),
                  boxShape: NeumorphicBoxShape.roundRect(
                      BorderRadius.circular(8)),
                  style: NeumorphicStyle(
                    depth: isPlaying ? -4 : 0,
                  ),
                  child: ListTile(
                      leading: Material(
                        shape: CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          item.imageUrl,
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(item.name,
                          style: TextStyle(
                            color: isPlaying ? Colors.blue : Colors.black,
                          )),
                      onTap: () {
                        this.onSelected(item);
                      }),
                );
              },
              itemCount: this.audios.length,
            ),
          ),
          FractionallySizedBox(
            widthFactor: 1,
            child: NeumorphicButton(
              onClick: () {
                this.onPlaylistSelected(this.audios);
              },
              child: Center(child: Text("All as playlist")),
            ),
          )
        ],
      ),
    );
  }
}
