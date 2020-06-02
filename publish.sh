flutter format lib/
pub publish --force

cd assets_audio_player_web
./publish.sh

git commit -am "published" && git push