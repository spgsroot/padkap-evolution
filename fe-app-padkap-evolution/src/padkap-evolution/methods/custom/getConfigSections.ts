import { PadkapEvolution } from '../../types';
import { PADKAP_EVOLUTION_UCI_PACKAGE } from '../../../constants';

export async function getConfigSections(): Promise<
  PadkapEvolution.ConfigSection[]
> {
  return uci
    .load(PADKAP_EVOLUTION_UCI_PACKAGE)
    .then(() => uci.sections(PADKAP_EVOLUTION_UCI_PACKAGE));
}
