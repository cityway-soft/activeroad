sudo apt-get install -qq libgeos++-dev libproj-dev build-essential liblzo2-dev liblzma-dev zlib1g-dev libprotobuf-c0-dev postgresql-contrib-9.3 postgresql-9.3-postgis-2.1-scripts libprotobuf-c0 zlib1g

# Se placer dans le dossier /tmp
cd /tmp

# Installer kyotocabinet
wget http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz
tar xzf kyotocabinet-1.2.76.tar.gz
cd kyotocabinet-1.2.76
./configure –enable-zlib –enable-lzo –enable-lzma --prefix=/usr && make
sudo make install

# Installer les bindings ruby pour kyotocabinet
cd /tmp
wget http://fallabs.com/kyotocabinet/rubypkg/kyotocabinet-ruby-1.32.tar.gz
tar xzf kyotocabinet-ruby-1.32.tar.gz
cd kyotocabinet-ruby-1.32
ruby extconf.rb
make
sudo make install
