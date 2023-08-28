import {IIdTokenClaims} from "../types";

export const removeNonceIfEmpty = (obj: IIdTokenClaims): IIdTokenClaims => {
    if ('nonce' in obj && obj.nonce === '') {
        delete obj.nonce;
    }
    return obj;
};

export const removeTrailingSlash = (str: string): string => str.endsWith('/') ? str.slice(0, -1) : str;

export const buildUriParams = (vars: Record<string, any>): string => Object.keys(vars)
    .reduce((a, k) => {
        a.push(`${k}=${encodeURIComponent(vars[k])}`);
        return a;
    }, [])
    .join('&');


export const port: number = parseInt(process.env.APP_PORT, 10) || 3001;
export const auth0Url: string = process.env.AUTH0_DOMAIN || 'http://localhost:' + port;
