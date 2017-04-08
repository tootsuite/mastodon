import en from './en';
import de from './de';
import es from './es';
import hu from './hu';
import fr from './fr';
import pt from './pt';
import uk from './uk';
import fi from './fi';
import co from './co';
import eo from './eo';

const locales = {
  en,
  de,
  es,
  hu,
  fr,
  pt,
  uk,
  fi,
  co,
  eo,
};

export default function getMessagesForLocale (locale) {
  return locales[locale];
};
