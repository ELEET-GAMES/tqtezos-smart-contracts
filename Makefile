all: fa2_multi_asset fa2_granular_multi_asset fa2_multi_token fa2_single_asset fa2_single_asset_with_hooks fa2_single_token fa2_nft_asset fa2_nft_token;

fa2_multi_asset:
	ligo compile contract multi_asset/ligo/src/fa2_multi_asset.mligo --entry-point multi_asset_main > build/fa2_multi_asset_contract.tz
	ligo compile storage multi_asset/ligo/src/fa2_multi_asset.mligo --entry-point multi_asset_main store > build/fa2_multi_asset_storage.tz

fa2_granular_multi_asset:
#	ligo compile contract multi_asset/ligo/src/fa2_granular_multi_asset.mligo --entry-point multi_asset_main > build/fa2_granular_multi_asset_contract.tz
	ligo compile storage multi_asset/ligo/src/fa2_multi_asset.mligo --entry-point multi_asset_main store > build/fa2_granular_multi_asset_storage.tz

fa2_multi_token:
	ligo compile contract multi_asset/ligo/src/fa2_multi_token.mligo --entry-point fa2_main  > build/fa2_multi_token_contract.tz
#	ligo compile storage multi_asset/ligo/src/fa2_multi_token.mligo --entry-point fa2_main storage > build/fa2_multi_token_storage.tz

fa2_single_asset:
#	ligo compile contract single_asset/ligo/src/fa2_single_asset.mligo --entry-point single_asset_main  > build/fa2_single_asset_contract.tz
#	ligo compile storage single_asset/ligo/src/fa2_single_asset.mligo --entry-point single_asset_main > build/fa2_single_asset_storage.tz


fa2_single_asset_with_hooks:
#	ligo compile contract single_asset/ligo/src/fa2_single_asset_with_hooks.mligo --entry-point fa2_main  > build/fa2_single_asset_with_hooks_contract.tz
#	ligo compile storage single_asset/ligo/src/fa2_single_asset_with_hooks.mligo --entry-point fa2_main storage > build/fa2_single_asset_with_hooks_storage.tz

fa2_single_token:
#	ligo compile contract single_asset/ligo/src/fa2_single_token.mligo --entry-point fa2_main  > build/fa2_single_token_contract.tz
#	ligo compile storage single_asset/ligo/src/fa2_single_token.mligo --entry-point fa2_main storage > build/fa2_single_token_storage.tz

fa2_nft_asset:
	ligo compile contract nft_assets/ligo/src/fa2_nft_asset.mligo --entry-point nft_asset_main  > build/fa2_nft_asset_contract.tz
	ligo compile storage nft_assets/ligo/src/fa2_nft_asset.mligo --entry-point nft_asset_main store > build/fa2_nft_asset_storage.tz
fa2_nft_token:
	ligo compile contract nft_assets/ligo/src/fa2_nft_token.mligo --entry-point nft_token_main  > build/fa2_nft_token_contract.tz
#	ligo compile storage nft_assets/ligo/src/fa2_nft_token.mligo --entry-point nft_token_main storage > build/fa2_nft_token_storage.tz


