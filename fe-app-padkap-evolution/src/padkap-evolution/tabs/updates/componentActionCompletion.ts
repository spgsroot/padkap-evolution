import type { PadkapEvolution } from '../../types';

export function shouldApplyCompletedComponentActionResult(
  result: Pick<PadkapEvolution.ComponentActionResult, 'action'>,
  notify: boolean,
) {
  return result.action !== 'check_update' || notify;
}
