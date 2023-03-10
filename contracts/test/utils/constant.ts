import {BigNumber, utils} from "ethers";

export const MaxUint128 = BigNumber.from(2).pow(128).sub(1);

export const ADMIN_ROLE = utils.keccak256(utils.toUtf8Bytes("ADMIN"));
