// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

contract Queue {
	mapping(uint256 => uint32) queue;
	uint256 first = 1;
	uint256 last = 0;

	function enqueue(uint32 data) public {
		last += 1;
		queue[last] = data;
	}

	function dequeue() public returns (uint32 data) {
		require(last >= first, "Queue is Empty");
		data = queue[first];
		delete queue[first];
		first += 1;
	}
}