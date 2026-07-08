abstract final class EmailDomainData {
  static const List<String> popularDomains = [
    'gmail.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'yahoo.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'aol.com',
    'mail.com',
    'proton.me',
    'protonmail.com',

    // Canada common
    'rogers.com',
    'bell.net',
    'shaw.ca',
    'telus.net',
    'videotron.ca',
    'sympatico.ca',
  ];

  static const Set<String> popularDomainsSet = {
    'gmail.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'yahoo.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'aol.com',
    'mail.com',
    'proton.me',
    'protonmail.com',
    'rogers.com',
    'bell.net',
    'shaw.ca',
    'telus.net',
    'videotron.ca',
    'sympatico.ca',
  };

  static const Map<String, String> commonTypos = {
    'gmial.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gnail.com': 'gmail.com',

    'outlok.com': 'outlook.com',
    'outllok.com': 'outlook.com',
    'otlook.com': 'outlook.com',
    'outlook.co': 'outlook.com',
    'outlook.con': 'outlook.com',

    'hotnail.com': 'hotmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmail.co': 'hotmail.com',
    'hotmail.con': 'hotmail.com',

    'yaho.com': 'yahoo.com',
    'yaoo.com': 'yahoo.com',
    'yahoo.co': 'yahoo.com',
    'yahoo.con': 'yahoo.com',

    'iclod.com': 'icloud.com',
    'icoud.com': 'icloud.com',
    'icloud.co': 'icloud.com',
    'icloud.con': 'icloud.com',

    'protonmai.com': 'protonmail.com',
    'protonmail.co': 'protonmail.com',

    'bell.et': 'bell.net',
    'telus.et': 'telus.net',
    'shw.ca': 'shaw.ca',
    'roges.com': 'rogers.com',
    'videotron.com': 'videotron.ca',
  };
}