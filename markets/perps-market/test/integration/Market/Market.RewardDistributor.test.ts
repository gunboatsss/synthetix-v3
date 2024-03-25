import { ethers } from 'ethers';
import { bn, bootstrapMarkets } from '../bootstrap';
import assert from 'assert';
import assertRevert from '@synthetixio/core-utils/utils/assertions/assert-revert';
import assertEvent from '@synthetixio/core-utils/utils/assertions/assert-event';
import assertBn from '@synthetixio/core-utils/utils/assertions/assert-bignumber';
import { createRewardsDistributor } from '../bootstrap';

describe('PerpsMarket: Reward Distributor configuration test', () => {
  const { systems, signers, owner, synthMarkets } = bootstrapMarkets({
    synthMarkets: [
      {
        name: 'Bitcoin',
        token: 'snxBTC',
        buyPrice: bn(10_000),
        sellPrice: bn(10_000),
      },
    ],
    perpsMarkets: [], // don't create a market in bootstrap
    traderAccountIds: [2, 3],
    collateralLiquidateRewardRatio: bn(0.42),
    skipRegisterDistributors: true,
  });

  let randomAccount: ethers.Signer;

  let synthBTCMarketId: ethers.BigNumber;

  before('identify actors', async () => {
    [, , , , randomAccount] = signers();
    synthBTCMarketId = synthMarkets()[0].marketId(); // 2
  });

  describe('initial configuration', () => {
    it('collateral liquidate reward ratio', async () => {
      assertBn.equal(await systems().PerpsMarket.getCollateralLiquidateRewardRatio(), bn(0.42));
    });
  });

  describe('attempt to change configuration errors', () => {
    it('reverts setting collateral liquidate reward ratio as non-owner', async () => {
      await assertRevert(
        systems().PerpsMarket.connect(randomAccount).setCollateralLiquidateRewardRatio(bn(0.1337)),
        'Unauthorized'
      );
    });

    it('reverts registering a new distributor as non-owner', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(randomAccount)
          .registerDistributor(
            await randomAccount.getAddress(),
            ethers.constants.AddressZero,
            synthBTCMarketId,
            []
          ),
        'Unauthorized'
      );
    });

    it('reverts registering a new distributor with wrong data: collateralId', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            await randomAccount.getAddress(),
            ethers.constants.AddressZero,
            42,
            []
          ),
        'InvalidId("42")'
      );
    });

    it('reverts registering a new distributor with wrong data: poolDelegatedCollateralTypes empty', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            await randomAccount.getAddress(),
            ethers.constants.AddressZero,
            synthBTCMarketId,
            []
          ),
        'InvalidParameter("collateralTypes", "must not be empty")'
      );
    });

    it('reverts registering a new distributor with wrong data: poolDelegatedCollateralTypes includes zeroAddress', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            await randomAccount.getAddress(),
            ethers.constants.AddressZero,
            synthBTCMarketId,
            [ethers.constants.AddressZero]
          ),
        'ZeroAddress'
      );
    });

    it('reverts registering a new distributor with wrong data: token is zeroAddress', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            synthBTCMarketId,
            [await randomAccount.getAddress()]
          ),
        'ZeroAddress'
      );
    });

    it('reverts registering a new distributor with wrong data: wrong distributor contract', async () => {
      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            await randomAccount.getAddress(),
            await randomAccount.getAddress(),
            synthBTCMarketId,
            [await randomAccount.getAddress()]
          ),
        'InvalidDistributorContract'
      );
    });

    it('reverts registering a new distributor with wrong data: wrong distributor (wrong token)', async () => {
      const wrongTokenAddress = await randomAccount.getAddress();
      const distributorAddress = await createRewardsDistributor(
        owner(),
        systems().Core,
        systems().PerpsMarket,
        1,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        18,
        synthBTCMarketId
      );

      await assertRevert(
        systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            wrongTokenAddress, // token
            distributorAddress,
            synthBTCMarketId,
            [await randomAccount.getAddress()]
          ),
        `InvalidDistributor("${synthBTCMarketId}", "${wrongTokenAddress}")`
      );
    });
  });

  describe('update configuration', () => {
    describe('set collateral liquidate reward ratio', () => {
      let tx: ethers.ContractTransaction;

      before('set collateral liquidate reward ratio', async () => {
        tx = await systems()
          .PerpsMarket.connect(owner())
          .setCollateralLiquidateRewardRatio(bn(0.1337));
      });

      it('emits event', async () => {
        await assertEvent(
          tx,
          `CollateralLiquidateRewardRatioSet(${bn(0.1337).toString()})`,
          systems().PerpsMarket
        );
      });

      it('collateral liquidate reward ratio is set', async () => {
        assertBn.equal(await systems().PerpsMarket.getCollateralLiquidateRewardRatio(), bn(0.1337));
      });
    });

    describe('register distributor', () => {
      let tx: ethers.ContractTransaction;
      let distributorAddress: string;
      let poolDelegatedCollateralTypes: string[];

      before('register distributor', async () => {
        const tokenAddress = await randomAccount.getAddress();

        poolDelegatedCollateralTypes = [await randomAccount.getAddress()];
        distributorAddress = await createRewardsDistributor(
          owner(),
          systems().Core,
          systems().PerpsMarket,
          1,
          ethers.constants.AddressZero,
          tokenAddress,
          18,
          synthBTCMarketId
        );
        tx = await systems()
          .PerpsMarket.connect(owner())
          .registerDistributor(
            tokenAddress,
            distributorAddress,
            synthBTCMarketId,
            poolDelegatedCollateralTypes
          );
      });

      it('distribution address is not zero', async () => {
        assert.notEqual(distributorAddress, ethers.constants.AddressZero);
      });

      it('emits event', async () => {
        await assertEvent(
          tx,
          `RewardDistributorRegistered("${distributorAddress}")`,
          systems().PerpsMarket
        );
      });

      it('distributor is registered', async () => {
        const registeredDistributorData =
          await systems().PerpsMarket.getRegisteredDistributor(synthBTCMarketId);
        assert.equal(registeredDistributorData.distributor, distributorAddress);

        assert.equal(registeredDistributorData.poolDelegatedCollateralTypes.length, 1);
        assert.equal(
          registeredDistributorData.poolDelegatedCollateralTypes[0],
          poolDelegatedCollateralTypes[0]
        );
      });
    });
  });
});
