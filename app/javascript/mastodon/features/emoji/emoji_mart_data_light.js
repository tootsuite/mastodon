// The output of this module is designed to mimic emoji-mart's
// "data" object, such that we can use it for a light version of emoji-mart's
// emojiIndex.search functionality.
const { unicodeToUnifiedName } = require('./unicode_to_unified_name');
const [ shortCodesToEmojiData, skins, categories, short_names ] = require('./emoji_compressed');

const emojis = {};

// decompress
Object.keys(shortCodesToEmojiData).forEach((shortCode) => {
  let [
    filenameData, // eslint-disable-line @typescript-eslint/no-unused-vars
    searchData,
  ] = shortCodesToEmojiData[shortCode];
  let [
    native,
    short_names,
    search,
    unified,
  ] = searchData;

  if (!unified) {
    // unified name can be derived from unicodeToUnifiedName
    unified = unicodeToUnifiedName(native);
  }

  short_names = [shortCode].concat(short_names);
  emojis[shortCode] = {
    native,
    search,
    short_names,
    unified,
  };
});

module.exports = {
  emojis,
  skins,
  categories,
  short_names,
};
