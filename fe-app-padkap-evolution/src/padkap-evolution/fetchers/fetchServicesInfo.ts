import { PadkapEvolutionShellMethods } from '../methods';
import { logger } from '../services/logger.service';
import { store } from '../services/store.service';
import { refreshRuntimeUiState } from '../services/runtimeUiState.service';
import { PadkapEvolution } from '../types';

let latestServicesInfoRequestId = 0;

function getSettledMethodResponse<T>(
  scope: string,
  result: PromiseSettledResult<PadkapEvolution.MethodResponse<T>>,
): PadkapEvolution.MethodResponse<T> {
  if (result.status === 'fulfilled') {
    return result.value;
  }

  logger.error('[SERVICES_INFO]', `${scope} failed`, result.reason);

  return {
    success: false,
    error: result.reason instanceof Error ? result.reason.message : '',
  };
}

export async function fetchServicesInfo() {
  const requestId = ++latestServicesInfoRequestId;
  const uiState = await refreshRuntimeUiState({ force: true });

  if (requestId !== latestServicesInfoRequestId) {
    return;
  }

  if (uiState) {
    return uiState;
  }

  const [padkapEvolutionResult, singboxResult] = await Promise.allSettled([
    PadkapEvolutionShellMethods.getStatus(),
    PadkapEvolutionShellMethods.getSingBoxStatus(),
  ]);

  if (requestId !== latestServicesInfoRequestId) {
    return;
  }

  const padkapEvolution = getSettledMethodResponse(
    'getStatus',
    padkapEvolutionResult,
  );
  const singbox = getSettledMethodResponse('getSingBoxStatus', singboxResult);
  const previousData = store.get().servicesInfoWidget.data;

  store.set({
    servicesInfoWidget: {
      loading: false,
      failed: !padkapEvolution.success || !singbox.success,
      data: {
        singbox: singbox.success ? singbox.data.running : previousData.singbox,
        padkapEvolutionRunning: padkapEvolution.success
          ? padkapEvolution.data.running
          : previousData.padkapEvolutionRunning,
        padkapEvolutionEnabled: padkapEvolution.success
          ? padkapEvolution.data.enabled
          : previousData.padkapEvolutionEnabled,
        padkapEvolutionStatus: padkapEvolution.success
          ? padkapEvolution.data.status
          : previousData.padkapEvolutionStatus,
      },
    },
  });

  return undefined;
}
