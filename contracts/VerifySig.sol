//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

/**
 * message to sign
 *hasn(message)
 *sign(hash(message),privatekey) off-chain(this is prefixed with some strig and hashed again)
 *ecrecover (hash(message),signature)
 *
 */
contract VerifySig {
    function verify(
        address _signer,
        string memory _message,
        uint _nonce,
        uint256 _amount,
        bytes memory _signature
    ) external pure returns (bool) {
        //hash the message
        bytes32 messageHash = getMessageHash(_message, _nonce, _amount);
        //signature is generated for messageHash 
        //generate ethSigned msg 
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recover(ethSignedMessageHash, _signature) == _signer;
    }

    function getMessageHash(string memory _message, uint _nonce , uint256 _amount )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_message, _nonce, _amount));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recover(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = _split(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    //split signature
    //_signature pointer
    function _split(bytes memory _signature)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(_signature.length == 65, "invalid signature");
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
    }
}
