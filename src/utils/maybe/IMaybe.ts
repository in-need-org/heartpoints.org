import { Mapper } from "../axioms/Mapper";
import { MaybeFlatmapper } from "./MaybeFlatmapper";
import { NoneType } from "./NoneType";
import { SomeType } from "./SomeType";

export interface IMaybe<T = any> {
    map<S>(f:Mapper<T, S>):IMaybe<S>
    flatMap<S>(f:MaybeFlatmapper<T, S>):IMaybe<S>
    hasValue():this is SomeType<T>
    valueOrDefault<S>(someDefault:S):T | S
    isNone():this is NoneType
    value:T //todo: remove when ready to handle all the breaking stuff in restguru!
    ifElse<S, R>(valueIfSomeObject:S, valueIfNone:R):S | R
}