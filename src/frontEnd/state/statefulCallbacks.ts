import { makeStatefulCallback } from "./makeStatefulCallback";
import { mapProperties } from "../../utils/list/mapProperties";
import { stateUpdatingCallbacks } from "./stateUpdatingCallbacks";

export const statefulCallbacks = (state, renderApp) => mapProperties(stateUpdatingCallbacks, stateUpdatingCallback => makeStatefulCallback(state, stateUpdatingCallback));
