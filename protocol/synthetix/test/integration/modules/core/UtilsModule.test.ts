import assert from 'assert/strict';
import { bootstrap } from '../../bootstrap';
import { ethers } from 'ethers';
import assertRevert from '@synthetixio/core-utils/utils/assertions/assert-revert';

describe('UtilsModule', function () {
  const { systems, signers } = bootstrap();

  let owner: ethers.Signer, user1: ethers.Signer;

  before('identify signers', async () => {
    [owner, user1] = signers();
  });

  describe('configureOracleManager()', () => {
    it('is only owner', async () => {
      await assertRevert(
        systems().Core.connect(user1).configureOracleManager(ethers.constants.AddressZero),
        `Unauthorized("${await user1.getAddress()}")`,
        systems().Core
      );
    });

    describe('on success', () => {
      before('call', async () => {
        await systems().Core.connect(owner).configureOracleManager(user1.getAddress());
      });

      it('sets oracle manager address', async () => {
        assert.equal(await systems().Core.getOracleManager(), await user1.getAddress());
      });
    });
  });

  describe('setConfig()', () => {
    it('is only owner', async () => {
      await assertRevert(
        systems()
          .Core.connect(user1)
          .setConfig(ethers.constants.HashZero, ethers.constants.HashZero),
        `Unauthorized("${await user1.getAddress()}")`,
        systems().Core
      );
    });

    describe('on success', () => {
      before('call', async () => {
        await systems()
          .Core.connect(owner)
          .setConfig(
            ethers.utils.formatBytes32String('wohoo'),
            ethers.utils.formatBytes32String('foo')
          );
      });

      it('sets config value', async () => {
        assert.equal(
          await systems().Core.getConfig(ethers.utils.formatBytes32String('wohoo')),
          ethers.utils.formatBytes32String('foo')
        );
      });
    });
  });
});
