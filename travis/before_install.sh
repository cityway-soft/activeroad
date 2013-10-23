if [[ "$POSTGIS" == "2.0" ]]; then
  echo "yes" | sudo apt-add-repository ppa:ubuntugis/ubuntugis-unstable
fi

sudo apt-get update
sudo apt-get install -qq libgeos-dev libproj-dev postgresql-9.1-postgis liblzo2-dev liblzma-dev zlib1g-dev build-essential

# Se placer dans le dossier /tmp
cd /tmp

# Installer kyotocabinet
wget http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz
tar xzf kyotocabinet-1.2.76.tar.gz
cd kyotocabinet-1.2.76
./configure –enable-zlib –enable-lzo –enable-lzma && make
sudo make install

# Installer les bindings ruby pour kyotocabinet
cd /tmp
wget http://fallabs.com/kyotocabinet/rubypkg/kyotocabinet-ruby-1.32.tar.gz
tar xzf kyotocabinet-ruby-1.32.tar.gz
cd kyotocabinet-ruby-1.32
ruby extconf.rb
make
sudo make install

if [[ "$POSTGIS" == "2.0" ]]; then
  sudo apt-get install -qq libgeos++-dev
fi
