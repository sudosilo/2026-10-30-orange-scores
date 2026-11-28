// Update manifests. Every shipped copy of a game asks for its manifest when it starts.
// version: newest release. modules: code files the shell loads, each with its own version.
// To ship an update, raise the numbers here and push.

module.exports = {
  mobbyhill: {
    name: 'MobbyHill',
    version: '1.0.0',
    released: '2026-11-28',
    notes: 'First release.',
    download: '',
    modules: [
      { name: 'data', url: 'https://mobbyhill.vercel.app/data.js', sha256: 'df437185cdb875b0756a17f47c683b9044566748548bb1eb62d07fa6216d80ae' },
      { name: 'game', url: 'https://mobbyhill.vercel.app/game.js', sha256: 'a5a411f0d31408945eb6151a0e88f848c1d0d01318fc15f5df08c8fc76c2fcc1' }
    ]
  }
};
