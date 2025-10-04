# NFT Floor Price Crash Trap - Makefile

# Load environment variables
-include .env
export

# Network configurations
HOODI_TESTNET_RPC := https://ethereum-hoodi-rpc.publicnode.com
CHAIN_ID := 560048

# Build & Test
.PHONY: build
build:
	forge build

.PHONY: test
test:
	forge test -vvv

.PHONY: clean
clean:
	forge clean

# Deploy
.PHONY: deploy-hoodi
deploy-hoodi:
	forge script script/Deploy.s.sol --rpc-url $(HOODI_TESTNET_RPC) --private-key $(PRIVATE_KEY) --broadcast --verify

.PHONY: deploy-local
deploy-local:
	forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast

# Utilities
.PHONY: get-address
get-address:
	cast wallet address --private-key $(PRIVATE_KEY)

.PHONY: get-balance
get-balance:
	cast balance $$(cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(HOODI_TESTNET_RPC)

# Help
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  build           - Compile contracts"
	@echo "  test            - Run tests"
	@echo "  deploy-hoodi    - Deploy to Hoodi testnet"
	@echo "  get-address     - Get your wallet address"
	@echo "  get-balance     - Get your wallet balance"
	@echo "  clean           - Clean build files"
