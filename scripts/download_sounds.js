const fs = require('fs');
const path = require('path');
const https = require('https');

const sounds = [
  {
    name: 'incoming_ring.mp3',
    // 582 is beautiful modern Marimba ringtone
    url: 'https://assets.mixkit.co/active_storage/sfx/582/582-preview.mp3',
  },
  {
    name: 'outgoing_ring.mp3',
    // 1359 is soft subtle outgoing ringback tone
    url: 'https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3',
  },
  {
    name: 'message_received.mp3',
    url: 'https://assets.mixkit.co/active_storage/sfx/2354/2354-preview.mp3',
  },
  {
    name: 'message_sent.mp3',
    url: 'https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3',
  }
];

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    };
    https.get(options, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return download(res.headers.location, dest).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`Status ${res.statusCode} for ${url}`));
      }
      const file = fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', reject);
  });
}

async function run() {
  const targetDir = path.join(__dirname, '..', 'assets', 'sounds');
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  for (const sound of sounds) {
    const dest = path.join(targetDir, sound.name);
    try {
      console.log(`Downloading ${sound.name}...`);
      await download(sound.url, dest);
      const stats = fs.statSync(dest);
      console.log(`✅ Saved ${sound.name} (${stats.size} bytes)`);
    } catch (err) {
      console.error(`❌ Failed ${sound.name}: ${err.message}`);
    }
  }
  console.log('🎉 All sounds downloaded successfully!');
}

run();
