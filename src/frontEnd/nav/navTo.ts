import { history } from "./history";

export type NavTo<S> = (state:S, path:string, skipHistoryUpdate:boolean) => void
export const navTo = (state, path: string, skipHistoryUpdate:boolean = false) => {
    const url = state.url.setPath(path);

    //todo: sometimes need to have side effect sometimes not, seems like this should be extracted out / handled separate
    if(!skipHistoryUpdate) history().push(path); 
    
    return { ...state, url };
};
