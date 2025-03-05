// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Accounts} from "src/builder/Accounts.sol";
import {Across} from "src/builder/BridgeRoutes.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {Paycall} from "src/Paycall.sol";
import {Quotecall} from "src/Quotecall.sol";
import {BuilderPackHelper} from "src/builder/BuilderPackHelper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";
import {Quotes} from "src/builder/Quotes.sol";
import {Strings} from "src/builder/Strings.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {Arrays} from "src/builder/lib/Arrays.sol";

contract QuarkBuilderTest {
    uint256 constant BLOCK_TIMESTAMP = 123_456_789;

    address constant COMET_1_USDC = address(0xc3010a);
    address constant COMET_1_WETH = address(0xc3010b);
    address constant COMET_8453_USDC = address(0xc384530a);
    address constant COMET_8453_WETH = address(0xc384530b);

    address constant COMET_REWARDS_1 = address(0xFEEDBEEF1);
    address constant COMET_REWARDS_8453 = address(0xFEEDBEEF8453);

    address constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    address constant LINK_1 = address(0xfeed01);
    address constant LINK_7777 = address(0xfeed7777);
    address constant LINK_8453 = address(0xfeed8453);
    uint256 constant LINK_PRICE = 14e8;

    address constant USDC_1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_7777 = 0x8D89c5CaA76592e30e0410B9e68C0f235c62B312;
    address constant USDC_8453 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant USDC_PRICE = 1e8;

    address constant USDT_1 = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDT_7777 = address(0xDEADBEEF);
    address constant USDT_8453 = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    uint256 constant USDT_PRICE = 1e8;

    address constant WETH_1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WETH_7777 = address(0xDEEDBEEF);
    address constant WETH_8453 = 0x4200000000000000000000000000000000000006;
    uint256 constant WETH_PRICE = 3000e8;

    address constant WBTC_1 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WBTC_7777 = address(0xDEADBEEF);
    address constant WBTC_8453 = address(0xDEADBEEF);
    uint256 constant WBTC_PRICE = 66000e8;

    address constant CBETH_1 = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address constant CBETH_7777 = address(0xDEADBEEF);
    address constant CBETH_8453 = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    uint256 constant CBETH_PRICE = 3300e8;

    address constant ETH_USD_PRICE_FEED_1 = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant ETH_USD_PRICE_FEED_8453 = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;

    bytes32 constant ALICE_DEFAULT_SECRET = bytes32(uint256(12));
    bytes32 constant BOB_DEFAULT_SECRET = bytes32(uint256(2));
    bytes32 constant COB_DEFAULT_SECRET = bytes32(uint256(5));

    bytes32 constant QUOTE_ID = bytes32("QUOTE_ID");
    bytes constant ACROSS_UNIQUE_ID = Across.UNIQUE_IDENTIFIER;

    /**
     *
     * Fixture Functions
     *
     * @dev to avoid variable shadowing warnings and to provide a visual signifier when
     * a function call is used to mock some data, we suffix all of our fixture-generating
     * functions with a single underscore, like so: transferIntent_(...).
     */
    function quote_() internal pure returns (Quotes.Quote memory) {
        Quotes.NetworkOperationFee memory networkOperationFeeBase =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 0.3e8});

        Quotes.NetworkOperationFee memory networkOperationFeeMainnet =
            Quotes.NetworkOperationFee({chainId: 1, opType: Quotes.OP_TYPE_BASELINE, price: 3e8});

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] = networkOperationFeeBase;
        networkOperationFees[1] = networkOperationFeeMainnet;

        return quote_(networkOperationFees);
    }

    function quote_(uint256 chainId, uint256 price) internal pure returns (Quotes.Quote memory) {
        Quotes.NetworkOperationFee memory networkOperationFee =
            Quotes.NetworkOperationFee({chainId: chainId, opType: Quotes.OP_TYPE_BASELINE, price: price});

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] = networkOperationFee;

        return quote_(networkOperationFees);
    }

    function quote_(uint256[] memory chainIds, uint256[] memory prices) internal pure returns (Quotes.Quote memory) {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](chainIds.length);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            Quotes.NetworkOperationFee memory networkOperationFee =
                Quotes.NetworkOperationFee({chainId: chainIds[i], opType: Quotes.OP_TYPE_BASELINE, price: prices[i]});

            networkOperationFees[i] = networkOperationFee;
        }

        return quote_(networkOperationFees);
    }

    function quote_(Quotes.NetworkOperationFee[] memory networkOperationFees)
        internal
        pure
        returns (Quotes.Quote memory)
    {
        Quotes.AssetQuote memory assetQuoteUsd = Quotes.AssetQuote({symbol: "USD", price: 1e8});
        Quotes.AssetQuote memory assetQuoteUsdc = Quotes.AssetQuote({symbol: "USDC", price: 1e8});

        Quotes.AssetQuote[] memory assetQuotes = new Quotes.AssetQuote[](2);
        assetQuotes[0] = assetQuoteUsd;
        assetQuotes[1] = assetQuoteUsdc;

        return Quotes.Quote({
            quoteId: QUOTE_ID,
            issuedAt: 1704067200,
            expiresAt: 1704069200,
            assetQuotes: assetQuotes,
            networkOperationFees: networkOperationFees
        });
    }

    // TODO: refactor
    function chainAccountsList_(uint256 amount) internal pure returns (Accounts.ChainAccounts[] memory) {
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](3);

        Accounts.QuarkSecret[] memory quarkSecrets = new Accounts.QuarkSecret[](3);
        quarkSecrets[0] = quarkSecret_(address(0xa11ce), ALICE_DEFAULT_SECRET);
        quarkSecrets[1] = quarkSecret_(address(0xb0b), BOB_DEFAULT_SECRET);
        quarkSecrets[2] = quarkSecret_(address(0xc0b), COB_DEFAULT_SECRET);

        address[] memory accounts = new address[](3);
        accounts[0] = address(0xa11ce);
        accounts[1] = address(0xb0b);
        accounts[2] = address(0xc0b);

        uint256[] memory amounts_chain_1 = new uint256[](3);
        amounts_chain_1[0] = uint256(amount / 2);
        amounts_chain_1[1] = uint256(0);
        amounts_chain_1[2] = uint256(0);

        uint256[] memory amounts_chain_8453 = new uint256[](3);
        amounts_chain_8453[0] = uint256(0);
        amounts_chain_8453[1] = uint256(amount / 2);
        amounts_chain_8453[2] = uint256(0);

        uint256[] memory amounts_chain_7777 = new uint256[](3);
        amounts_chain_7777[0] = uint256(0);
        amounts_chain_7777[1] = uint256(0);
        amounts_chain_7777[2] = uint256(0);

        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets,
            assetPositionsList: assetPositionLists_(1, accounts, amounts_chain_1),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_(),
            morphoRewardDistributions: emptyMorphoRewardDistributions_()
        });
        chainAccountsList[1] = Accounts.ChainAccounts({
            chainId: 8453,
            quarkSecrets: quarkSecrets,
            assetPositionsList: assetPositionLists_(8453, accounts, amounts_chain_8453),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_(),
            morphoRewardDistributions: emptyMorphoRewardDistributions_()
        });
        chainAccountsList[2] = Accounts.ChainAccounts({
            chainId: 7777,
            quarkSecrets: quarkSecrets,
            assetPositionsList: assetPositionLists_(7777, accounts, amounts_chain_7777),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_(),
            morphoRewardDistributions: emptyMorphoRewardDistributions_()
        });
        return chainAccountsList;
    }

    function emptyCometPositions_() internal pure returns (Accounts.CometPositions[] memory) {
        Accounts.CometPositions[] memory emptyCometPositions = new Accounts.CometPositions[](0);
        return emptyCometPositions;
    }

    function emptyMorphoPositions_() internal pure returns (Accounts.MorphoPositions[] memory) {
        Accounts.MorphoPositions[] memory emptyMorphoPositions = new Accounts.MorphoPositions[](0);
        return emptyMorphoPositions;
    }

    function emptyMorphoVaultPositions_() internal pure returns (Accounts.MorphoVaultPositions[] memory) {
        Accounts.MorphoVaultPositions[] memory emptyMorphoVaultPositions = new Accounts.MorphoVaultPositions[](0);
        return emptyMorphoVaultPositions;
    }

    function emptyMorphoRewardDistributions_() internal pure returns (Accounts.MorphoRewardDistribution[] memory) {
        Accounts.MorphoRewardDistribution[] memory emptyMorphoRewardDistributions =
            new Accounts.MorphoRewardDistribution[](0);
        return emptyMorphoRewardDistributions;
    }

    function quarkSecrets_() internal pure returns (Accounts.QuarkSecret[] memory) {
        Accounts.QuarkSecret[] memory quarkSecrets = new Accounts.QuarkSecret[](1);
        quarkSecrets[0] = quarkSecret_();
        return quarkSecrets;
    }

    function chainCosts(uint256 chainId, uint256 amount) internal pure returns (PaymentInfo.ChainCost[] memory) {
        PaymentInfo.ChainCost[] memory chainCosts_ = new PaymentInfo.ChainCost[](1);
        chainCosts_[0] = PaymentInfo.ChainCost({chainId: chainId, amount: amount});
        return chainCosts_;
    }

    function assetPositionLists_(uint256 chainId, address[] memory accounts, uint256[] memory balances)
        internal
        pure
        returns (Accounts.AssetPositions[] memory)
    {
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](4);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(chainId),
            symbol: "USDC",
            decimals: 6,
            usdPrice: USDC_PRICE,
            accountBalances: accountsBalances_(accounts, balances)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: usdt_(chainId),
            symbol: "USDT",
            decimals: 6,
            usdPrice: USDT_PRICE,
            accountBalances: accountsBalances_(accounts, balances)
        });

        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(chainId),
            symbol: "WETH",
            decimals: 18,
            usdPrice: WETH_PRICE,
            accountBalances: accountsBalances_(accounts, balances)
        });

        uint256[] memory zeroBalances = new uint256[](accounts.length);

        assetPositionsList[3] = Accounts.AssetPositions({
            asset: link_(chainId),
            symbol: "LINK",
            decimals: 18,
            usdPrice: LINK_PRICE,
            accountBalances: accountsBalances_(accounts, zeroBalances) // empty balances
        });

        return assetPositionsList;
    }

    function assetPositionsList_(uint256 chainId, address account, uint256 balance)
        internal
        pure
        returns (Accounts.AssetPositions[] memory)
    {
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](5);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(chainId),
            symbol: "USDC",
            decimals: 6,
            usdPrice: USDC_PRICE,
            accountBalances: accountBalances_(account, balance)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: usdt_(chainId),
            symbol: "USDT",
            decimals: 6,
            usdPrice: USDT_PRICE,
            accountBalances: accountBalances_(account, balance)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(chainId),
            symbol: "WETH",
            decimals: 18,
            usdPrice: WETH_PRICE,
            accountBalances: accountBalances_(account, balance)
        });
        assetPositionsList[3] = Accounts.AssetPositions({
            asset: link_(chainId),
            symbol: "LINK",
            decimals: 18,
            usdPrice: LINK_PRICE,
            accountBalances: accountBalances_(account, 0) // empty balance
        });
        assetPositionsList[4] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: WETH_PRICE,
            accountBalances: accountBalances_(account, 0) // empty balance
        });
        return assetPositionsList;
    }

    function assetPositionsListUsdc_(uint256 chainId, address account, uint256 balance)
        internal
        pure
        returns (Accounts.AssetPositions[] memory)
    {
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](1);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(chainId),
            symbol: "USDC",
            decimals: 6,
            usdPrice: USDC_PRICE,
            accountBalances: accountBalances_(account, balance)
        });
        return assetPositionsList;
    }

    function accountsBalances_(address[] memory accounts, uint256[] memory balances)
        internal
        pure
        returns (Accounts.AccountBalance[] memory)
    {
        Accounts.AccountBalance[] memory accountsBalances = new Accounts.AccountBalance[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            accountsBalances[i] = Accounts.AccountBalance({account: accounts[i], balance: balances[i]});
        }
        return accountsBalances;
    }

    function accountBalances_(address account, uint256 balance)
        internal
        pure
        returns (Accounts.AccountBalance[] memory)
    {
        Accounts.AccountBalance[] memory accountBalances = new Accounts.AccountBalance[](1);
        accountBalances[0] = Accounts.AccountBalance({account: account, balance: balance});
        return accountBalances;
    }

    function wbtc_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return WBTC_1;
        if (chainId == 7777) return WBTC_7777;
        if (chainId == 8453) return WBTC_8453;
        revert("no mock WBTC for chain id");
    }

    function cbEth_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return CBETH_1;
        if (chainId == 7777) return CBETH_7777;
        if (chainId == 8453) return CBETH_8453;
        revert("no mock cbETH for chain id");
    }

    function link_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return LINK_1;
        if (chainId == 7777) return LINK_7777; // Mock with random chain's LINK
        if (chainId == 8453) return LINK_8453;
        revert("no mock LINK for chain id");
    }

    function usdc_(uint256 chainId) internal pure returns (address) {
        if (chainId == 7777) return USDC_7777; // Mock with random chain's USDC

        (string memory result, address assetAddress) = BuilderPackHelper.knownAssetAddress("USDC", chainId);

        if (Strings.isError(result)) {
            revert("no mock usdc for that chain id bye");
        }

        return assetAddress;
    }

    function usdt_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return USDT_1;
        if (chainId == 8453) return USDT_8453;
        if (chainId == 7777) return USDT_7777; // Mock with random chain's USDT
        revert("no mock usdt for that chain id bye");
    }

    function eth_() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function weth_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return WETH_1;
        if (chainId == 8453) return WETH_8453;
        if (chainId == 7777) return WETH_7777; // Mock with random chain's WETH
        revert("no mock weth for that chain id bye");
    }

    function paycallUsdc_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return CodeJarHelper.getCodeAddress(
                abi.encodePacked(type(Paycall).creationCode, abi.encode(ETH_USD_PRICE_FEED_1, USDC_1))
            );
        } else if (chainId == 8453) {
            return CodeJarHelper.getCodeAddress(
                abi.encodePacked(type(Paycall).creationCode, abi.encode(ETH_USD_PRICE_FEED_8453, USDC_8453))
            );
        } else {
            revert("no paycall address for chain id");
        }
    }

    function quotecallUsdc_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return CodeJarHelper.getCodeAddress(
                abi.encodePacked(type(Quotecall).creationCode, abi.encode(ETH_USD_PRICE_FEED_1, USDC_1))
            );
        } else if (chainId == 8453) {
            return CodeJarHelper.getCodeAddress(
                abi.encodePacked(type(Quotecall).creationCode, abi.encode(ETH_USD_PRICE_FEED_8453, USDC_8453))
            );
        } else {
            revert("no quotecall address for chain id");
        }
    }

    function cometUsdc_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return COMET_1_USDC;
        } else if (chainId == 8453) {
            return COMET_8453_USDC;
        } else {
            revert("no USDC Comet for chain id");
        }
    }

    function cometWeth_(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return COMET_1_WETH;
        } else if (chainId == 8453) {
            return COMET_8453_WETH;
        } else {
            revert("no WETH Comet for chain id");
        }
    }

    function quarkSecrets_(address account, bytes32 nonceSecret)
        internal
        pure
        returns (Accounts.QuarkSecret[] memory)
    {
        Accounts.QuarkSecret[] memory quarkSecrets = new Accounts.QuarkSecret[](1);
        quarkSecrets[0] = quarkSecret_(account, nonceSecret);
        return quarkSecrets;
    }

    function quarkSecret_() internal pure returns (Accounts.QuarkSecret memory) {
        return quarkSecret_(address(0xa11ce), bytes32(uint256(3)));
    }

    function quarkSecret_(address account, bytes32 nonceSecret) internal pure returns (Accounts.QuarkSecret memory) {
        return Accounts.QuarkSecret({account: account, nonceSecret: nonceSecret});
    }

    struct ChainPortfolio {
        uint256 chainId;
        address account;
        bytes32 nonceSecret;
        string[] assetSymbols;
        uint256[] assetBalances;
        CometPortfolio[] cometPortfolios;
        MorphoPortfolio[] morphoPortfolios;
        MorphoVaultPortfolio[] morphoVaultPortfolios;
        MorphoRewardPortfolio[] morphoRewardPortfolios;
    }

    struct CometPortfolio {
        address comet;
        uint256 baseSupplied;
        uint256 baseBorrowed;
        string[] collateralAssetSymbols;
        uint256[] collateralAssetBalances;
        string[] rewardAssetSymbols;
        address[] rewardContracts;
        uint256[] rewardsOwed;
    }

    struct MorphoPortfolio {
        bytes32 marketId;
        string loanToken;
        string collateralToken;
        uint256 borrowedBalance;
        uint256 collateralBalance;
    }

    struct MorphoVaultPortfolio {
        string assetSymbol;
        uint256 balance;
        address vault;
    }

    struct MorphoRewardPortfolio {
        string assetSymbol;
        uint256 claimable;
        address distributor;
        bytes32[] proof;
    }

    function emptyCometPortfolios_() internal pure returns (CometPortfolio[] memory) {
        CometPortfolio[] memory emptyCometPortfolios = new CometPortfolio[](0);
        return emptyCometPortfolios;
    }

    function emptyMorphoPortfolios_() internal pure returns (MorphoPortfolio[] memory) {
        MorphoPortfolio[] memory emptyMorphoPortfolios = new MorphoPortfolio[](0);
        return emptyMorphoPortfolios;
    }

    function emptyMorphoVaultPortfolios_() internal pure returns (MorphoVaultPortfolio[] memory) {
        MorphoVaultPortfolio[] memory emptyMorphoVaultPortfolios = new MorphoVaultPortfolio[](0);
        return emptyMorphoVaultPortfolios;
    }

    function emptyMorphoRewardPortfolios_() internal pure returns (MorphoRewardPortfolio[] memory) {
        MorphoRewardPortfolio[] memory emptyMorphoRewardPortfolios = new MorphoRewardPortfolio[](0);
        return emptyMorphoRewardPortfolios;
    }

    function chainAccountsFromChainPortfolios(ChainPortfolio[] memory chainPortfolios)
        internal
        pure
        returns (Accounts.ChainAccounts[] memory)
    {
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](chainPortfolios.length);
        for (uint256 i = 0; i < chainPortfolios.length; ++i) {
            chainAccountsList[i] = Accounts.ChainAccounts({
                chainId: chainPortfolios[i].chainId,
                quarkSecrets: quarkSecrets_(chainPortfolios[i].account, chainPortfolios[i].nonceSecret),
                assetPositionsList: assetPositionsForAssets(
                    chainPortfolios[i].chainId,
                    chainPortfolios[i].account,
                    chainPortfolios[i].assetSymbols,
                    chainPortfolios[i].assetBalances
                ),
                // cometPositions: cometPositionsFor
                cometPositions: cometPositionsForCometPorfolios(
                    chainPortfolios[i].chainId, chainPortfolios[i].account, chainPortfolios[i].cometPortfolios
                ),
                morphoPositions: morphoPositionsForMorphoPortfolios(
                    chainPortfolios[i].chainId, chainPortfolios[i].account, chainPortfolios[i].morphoPortfolios
                ),
                morphoVaultPositions: morphoVaultPositionsForMorphoVaultPortfolios(
                    chainPortfolios[i].chainId, chainPortfolios[i].account, chainPortfolios[i].morphoVaultPortfolios
                ),
                morphoRewardDistributions: morphoRewardDistributionsForMorphoRewardPortfolios(
                    chainPortfolios[i].chainId, chainPortfolios[i].account, chainPortfolios[i].morphoRewardPortfolios
                )
            });
        }

        return chainAccountsList;
    }

    function cometPositionsForCometPorfolios(uint256 chainId, address account, CometPortfolio[] memory cometPortfolios)
        internal
        pure
        returns (Accounts.CometPositions[] memory)
    {
        Accounts.CometPositions[] memory cometPositions = new Accounts.CometPositions[](cometPortfolios.length);

        for (uint256 i = 0; i < cometPortfolios.length; ++i) {
            CometPortfolio memory cometPortfolio = cometPortfolios[i];
            Accounts.CometCollateralPosition[] memory collateralPositions =
                new Accounts.CometCollateralPosition[](cometPortfolio.collateralAssetSymbols.length);
            Accounts.CometReward[] memory cometRewards =
                new Accounts.CometReward[](cometPortfolio.rewardAssetSymbols.length);

            for (uint256 j = 0; j < cometPortfolio.collateralAssetSymbols.length; ++j) {
                (address asset,,) = assetInfo(cometPortfolio.collateralAssetSymbols[j], chainId);
                collateralPositions[j] = Accounts.CometCollateralPosition({
                    asset: asset,
                    accounts: Arrays.addressArray(account),
                    balances: Arrays.uintArray(cometPortfolio.collateralAssetBalances[j])
                });
            }

            for (uint256 j = 0; j < cometPortfolio.rewardAssetSymbols.length; ++j) {
                (address asset,,) = assetInfo(cometPortfolio.rewardAssetSymbols[j], chainId);
                cometRewards[j] = Accounts.CometReward({
                    asset: asset,
                    rewardContract: cometPortfolio.rewardContracts[j],
                    accounts: Arrays.addressArray(account),
                    rewardsOwed: Arrays.uintArray(cometPortfolio.rewardsOwed[j])
                });
            }

            cometPositions[i] = Accounts.CometPositions({
                comet: cometPortfolio.comet,
                basePosition: Accounts.CometBasePosition({
                    asset: baseAssetForComet(chainId, cometPortfolio.comet),
                    accounts: Arrays.addressArray(account),
                    borrowed: Arrays.uintArray(cometPortfolio.baseBorrowed),
                    supplied: Arrays.uintArray(cometPortfolio.baseSupplied)
                }),
                collateralPositions: collateralPositions,
                cometRewards: cometRewards
            });
        }

        return cometPositions;
    }

    function morphoPositionsForMorphoPortfolios(
        uint256 chainId,
        address account,
        MorphoPortfolio[] memory morphoPortfolios
    ) internal pure returns (Accounts.MorphoPositions[] memory) {
        Accounts.MorphoPositions[] memory morphoPositions = new Accounts.MorphoPositions[](morphoPortfolios.length);

        for (uint256 i = 0; i < morphoPortfolios.length; ++i) {
            MorphoPortfolio memory morphoPortfolio = morphoPortfolios[i];
            (address loanAsset,,) = assetInfo(morphoPortfolio.loanToken, chainId);
            (address collateralAsset,,) = assetInfo(morphoPortfolio.collateralToken, chainId);

            morphoPositions[i] = Accounts.MorphoPositions({
                marketId: morphoPortfolio.marketId,
                morpho: MorphoInfo.getMorphoAddress(chainId),
                loanToken: loanAsset,
                collateralToken: collateralAsset,
                borrowPosition: Accounts.MorphoBorrowPosition({
                    accounts: Arrays.addressArray(account),
                    borrowed: Arrays.uintArray(morphoPortfolio.borrowedBalance)
                }),
                collateralPosition: Accounts.MorphoCollateralPosition({
                    accounts: Arrays.addressArray(account),
                    balances: Arrays.uintArray(morphoPortfolio.collateralBalance)
                })
            });
        }

        return morphoPositions;
    }

    function morphoVaultPositionsForMorphoVaultPortfolios(
        uint256 chainId,
        address account,
        MorphoVaultPortfolio[] memory morphoVaultPortfolios
    ) internal pure returns (Accounts.MorphoVaultPositions[] memory) {
        Accounts.MorphoVaultPositions[] memory morphoVaultPositions =
            new Accounts.MorphoVaultPositions[](morphoVaultPortfolios.length);
        for (uint256 i = 0; i < morphoVaultPortfolios.length; ++i) {
            MorphoVaultPortfolio memory morphoVaultPortfolio = morphoVaultPortfolios[i];
            (address asset,,) = assetInfo(morphoVaultPortfolio.assetSymbol, chainId);
            morphoVaultPositions[i] = Accounts.MorphoVaultPositions({
                asset: asset,
                accounts: Arrays.addressArray(account),
                balances: Arrays.uintArray(morphoVaultPortfolio.balance),
                vault: morphoVaultPortfolio.vault
            });
        }

        return morphoVaultPositions;
    }

    function morphoRewardDistributionsForMorphoRewardPortfolios(
        uint256 chainId,
        address account,
        MorphoRewardPortfolio[] memory morphoRewardPortfolios
    ) internal pure returns (Accounts.MorphoRewardDistribution[] memory) {
        Accounts.MorphoRewardDistribution[] memory morphoRewardDistributions =
            new Accounts.MorphoRewardDistribution[](morphoRewardPortfolios.length);
        for (uint256 i = 0; i < morphoRewardPortfolios.length; ++i) {
            MorphoRewardPortfolio memory morphoRewardPortfolio = morphoRewardPortfolios[i];
            (address asset,,) = assetInfo(morphoRewardPortfolio.assetSymbol, chainId);
            morphoRewardDistributions[i] = Accounts.MorphoRewardDistribution({
                account: account,
                asset: asset,
                claimable: morphoRewardPortfolio.claimable,
                distributor: morphoRewardPortfolio.distributor,
                proof: morphoRewardPortfolio.proof
            });
        }

        return morphoRewardDistributions;
    }

    function baseAssetForComet(uint256 chainId, address comet) internal pure returns (address) {
        if (comet == COMET_1_USDC || comet == COMET_8453_USDC) {
            return usdc_(chainId);
        } else if (comet == COMET_1_WETH || comet == COMET_8453_WETH) {
            return weth_(chainId);
        } else {
            revert("unknown chainId/comet combination");
        }
    }

    function assetPositionsForAssets(
        uint256 chainId,
        address account,
        string[] memory assetSymbols,
        uint256[] memory assetBalances
    ) internal pure returns (Accounts.AssetPositions[] memory) {
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](assetSymbols.length);

        for (uint256 i = 0; i < assetSymbols.length; ++i) {
            (address asset, uint256 decimals, uint256 price) = assetInfo(assetSymbols[i], chainId);
            assetPositionsList[i] = Accounts.AssetPositions({
                asset: asset,
                symbol: assetSymbols[i],
                decimals: decimals,
                usdPrice: price,
                accountBalances: accountBalances_(account, assetBalances[i])
            });
        }

        return assetPositionsList;
    }

    function assetInfo(string memory assetSymbol, uint256 chainId) internal pure returns (address, uint256, uint256) {
        if (Strings.stringEq(assetSymbol, "USDC")) {
            return (usdc_(chainId), 6, USDC_PRICE);
        } else if (Strings.stringEq(assetSymbol, "USDT")) {
            return (usdt_(chainId), 6, USDT_PRICE);
        } else if (Strings.stringEq(assetSymbol, "WETH")) {
            return (weth_(chainId), 18, WETH_PRICE);
        } else if (Strings.stringEq(assetSymbol, "ETH")) {
            return (eth_(), 18, WETH_PRICE);
        } else if (Strings.stringEq(assetSymbol, "LINK")) {
            return (link_(chainId), 18, LINK_PRICE);
        } else if (Strings.stringEq(assetSymbol, "WBTC")) {
            return (wbtc_(chainId), 8, WBTC_PRICE);
        } else if (Strings.stringEq(assetSymbol, "cbETH")) {
            return (cbEth_(chainId), 18, CBETH_PRICE);
        } else {
            revert("[Testlib QuarkBuilderTest]: unknown assetSymbol");
        }
    }
}
