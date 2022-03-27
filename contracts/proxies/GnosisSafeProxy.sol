// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title IProxy - Helper interface to access masterCopy of the Proxy on-chain
/// @author Richard Meissner - <richard@gnosis.io>
interface IProxy {
    function masterCopy() external view returns (address);
}

/// @title GnosisSafeProxy - Generic proxy contract allows to execute all transactions applying the code of a master contract.
/// @author Stefan George - <stefan@gnosis.io>
/// @author Richard Meissner - <richard@gnosis.io>
contract GnosisSafeProxy {
    // singleton always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    // To reduce deployment costs this variable is internal and needs to be retrieved via `getStorageAt`
    address internal singleton;

    /// @dev Constructor function sets address of singleton contract.
    /// @param _singleton Singleton address.
    constructor(address _singleton) {
        require(_singleton != address(0), "Invalid singleton address provided");
        singleton = _singleton;
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    fallback() external payable {
        // solhint-disable-next-line no-inline-assembly
        // 使用内联汇编
        // 每当合约将调用代理到另一个合同时，它都会在本合约的上下文中执行另一个合约的代码。
        // 这意味着将保留msg.value和msg.sender值，并且每次存储修改都会影响本合约。
        assembly {
            //通过opcode获取singleton，storage中都是按顺序储存。类似eth.getStorageAt(合约地址，slot)
            let _singleton := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000) {
                mstore(0, _singleton)
                return(0, 0x20)
            }
            //从调用数据的位置 f 的拷贝 s 个字节到内存的位置 t
            //calldatacopy(t, f, s)。calldatasize 调用数据的字节数大小
            calldatacopy(0, 0, calldatasize())
            //delegatecall(g, a, in, insize, out, outsize)
            //使用 mem[in...(in + insize)) 作为输入数据， 提供 g gas 对地址 a 发起消息调用， 输出结果数据保存在 mem[out...(out + outsize))， 发生错误（比如 gas 不足）时返回 0，正确结束返回 1
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            //returndatacopy(t, f, s) 从 returndata 的位置 f 拷贝 s 个字节到内存的位置 t
            //returndatasize() 最后一个returndata 的大小
            returndatacopy(0, 0, returndatasize())
            //判断如果失败，直接回滚
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
