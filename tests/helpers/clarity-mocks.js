// Helper functions to mock Clarity environment

/**
 * Mock block info for testing
 * @param {Object} blockInfo - Block information to mock
 */
export function mockClarityBlockInfo(blockInfo) {
	global.blockInfo = blockInfo
}

/**
 * Mock Bitcoin-related functions
 * @param {Object} bitcoinInfo - Bitcoin information to mock
 */
export function mockClarityBitcoin(bitcoinInfo) {
	global.bitcoinInfo = bitcoinInfo
}

/**
 * Helper to convert string to uint
 * @param {string} str - String to convert
 * @returns {bigint} - Converted bigint
 */
export function stringToUint(str) {
	return BigInt(Buffer.from(str).reduce((sum, byte) => sum + byte, 0))
}

/**
 * Helper to simulate contract call
 * @param {Object} contract - Contract object
 * @param {string} functionName - Function to call
 * @param {Array} args - Arguments to pass
 * @param {string} sender - Caller address
 * @returns {Object} - Result of the call
 */
export function simulateContractCall(contract, functionName, args, sender) {
	// Save current sender
	const currentSender = global.txSender
	
	// Set new sender for this call
	global.txSender = sender
	
	try {
		// Call the function
		const result = contract.functions[functionName](...args)
		return result
	} finally {
		// Restore original sender
		global.txSender = currentSender
	}
}

