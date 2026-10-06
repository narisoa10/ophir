/// The only currency Ophir supports. Amounts Ophir creates are in it; amounts
/// from outside (Plaid) keep their own currency and are never relabeled or
/// converted. The database counterpart is `public.product_currency_code()`.
const productCurrencyCode = 'CAD';
