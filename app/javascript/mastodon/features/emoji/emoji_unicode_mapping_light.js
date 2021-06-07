// A mapping of unicode strings to an object containing the filename
// (i.e. the svg filename) and a shortCode intended to be shown
// as a "title" attribute in an HTML element (aka tooltip).

const [
  shortCodesToEmojiData,
  skins, // eslint-disable-line @typescript-eslint/no-unused-vars
  categories, // eslint-disable-line @typescript-eslint/no-unused-vars
  short_names, // eslint-disable-line @typescript-eslint/no-unused-vars
  emojisWithoutShortCodes,
] = require('./emoji_compressed');
const { unicodeToFilename } = require('./unicode_to_filename');

// decompress
const unicodeMapping = {};

function processEmojiMapData(emojiMapData, shortCode) {
  let [ native, filename ] = emojiMapData;
  if (!filename) {
    // filename name can be derived from unicodeToFilename
    filename = unicodeToFilename(native);
  }
  unicodeMapping[native] = {
    shortCode: shortCode,
    filename: filename,
  };
}

Object.keys(shortCodesToEmojiData).forEach((shortCode) => {
  let [ filenameData ] = shortCodesToEmojiData[shortCode];
  filenameData.forEach(emojiMapData => processEmojiMapData(emojiMapData, shortCode));
});
emojisWithoutShortCodes.forEach(emojiMapData => processEmojiMapData(emojiMapData));

module.exports = unicodeMapping;
