// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

library ArrayLibrary {
    function removeAt(uint256[] storage self, uint256 index) public {
        self[index] = self[self.length - 1];
        self.pop();
    }

    function removeAt(address[] storage self, uint256 index) public {
        self[index] = self[self.length - 1];
        self.pop();
    }

    function findIndex(uint256[] memory self, uint256 value)
        public
        pure
        returns (uint256)
    {
        uint256 length = self.length;
        uint256 i;
        for (i = 0; i < length; ++i) {
            if (self[i] == value) {
                return i;
            }
        }
        return length;
    }

    function findIndex(address[] memory self, address value)
        public
        pure
        returns (uint256)
    {
        uint256 length = self.length;
        uint256 i;
        for (i = 0; i < length; ++i) {
            if (self[i] == value) {
                return i;
            }
        }
        return length;
    }

    function findMaxIndex(uint256[] memory self) public pure returns (uint256) {
        uint256 length = self.length;
        require(length > 0, "Empty Array");
        uint256 i;
        uint256 maxIdx = 0;
        for (i = 1; i < length; ++i) {
            if (self[i] > self[maxIdx]) {
                maxIdx = i;
            }
        }
        return maxIdx;
    }
}
