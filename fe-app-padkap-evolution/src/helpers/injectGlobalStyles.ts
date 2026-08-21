import { GlobalStyles } from '../styles';

const PADKAP_EVOLUTION_GLOBAL_STYLES_ID = 'padkap-evolution-global-styles';

export function injectGlobalStyles() {
  if (document.getElementById(PADKAP_EVOLUTION_GLOBAL_STYLES_ID)) {
    return;
  }

  document.head.insertAdjacentHTML(
    'beforeend',
    `
        <style id="${PADKAP_EVOLUTION_GLOBAL_STYLES_ID}">
          ${GlobalStyles}
        </style>
    `,
  );
}
