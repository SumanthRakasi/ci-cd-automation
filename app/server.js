const app = require('./src/app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT} (version ${process.env.APP_VERSION || 'dev'})`);
});
