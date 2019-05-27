import { Predicate, TypePredicate } from "./predicate";
import { Maybe, maybe, Some, None } from "./maybe";
import { Dictionary } from "lodash";
import * as _ from "lodash";
import { Mapper } from "./mapper";
import { Pair } from "./pair";

export const first = <T>(list:T[], predicate:Predicate<T>):Maybe<T> => 
    maybe(list.find(predicate))

export const firstTypeMatch = <T, S extends T>(list:T[], predicate:TypePredicate<T, S>):Maybe<S> => {
    for(const item of list) {
        if(predicate(item)) return Some(item)
    }
    return None
}

export const mapDictionary = <T, S>(obj:Dictionary<T>, keyMapper:Mapper<string, string>, valueMapper:Mapper<T, S>):{[k:string]:S} =>
    Object
        .entries(obj)
        .map(([k,v]) => ({newKey: keyMapper(k), newValue: valueMapper(v)}))
        .reduce((soFar, {newKey, newValue}) => ({...soFar, [newKey]: newValue}), {});

export const zip = <T, S>(ts:Array<T>, ss:Array<S>):Maybe<Array<Pair<T, S>>> => {
    return maybe(_.zip(ts, ss) as Array<Pair<T, S>>);
}