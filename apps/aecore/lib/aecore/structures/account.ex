defmodule Aecore.Structures.Account do
  @moduledoc """
  Aecore structure of a transaction data.
  """

  require Logger

  alias Aecore.Wallet.Worker, as: Wallet
  alias Aecore.Chain.Worker, as: Chain
  alias Aecore.Structures.SpendTx
  alias Aecore.Structures.Account
  alias Aecore.Structures.DataTx
  alias Aecore.Structures.SignedTx

  @type t :: %Account{
          balance: non_neg_integer(),
          nonce: non_neg_integer()
        }

  @doc """
  Definition of Account structure

  ## Parameters
  - nonce: Out transaction count
  - balance: The acccount balance
  """
  defstruct [:balance, :nonce]
  use ExConstructor

  @spec empty() :: Account.t()
  def empty() do
    %Account{balance: 0, nonce: 0}
  end

  @doc """
  Builds a SpendTx where the miners public key is used as a sender (from_acc)
  """
  @spec spend(Wallet.pubkey(), non_neg_integer(), non_neg_integer()) :: {:ok, SignedTx.t()}
  def spend(to_acc, amount, fee) do
    from_acc = Wallet.get_public_key()
    from_acc_priv_key = Wallet.get_private_key()
    nonce = Map.get(Chain.chain_state().accounts, from_acc, %{nonce: 0}).nonce + 1
    spend(from_acc, from_acc_priv_key, to_acc, amount, fee, nonce)
  end

  @doc """
  Build a SpendTx from the given sender keys to the receivers account
  """
  @spec spend(
          Wallet.pubkey(),
          Wallet.privkey(),
          Wallet.pubkey(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, SignedTx.t()}
  def spend(from_acc, from_acc_priv_key, to_acc, amount, fee, nonce) do
    payload = %{to_acc: to_acc, value: amount}
    spend_tx = DataTx.init(SpendTx, payload, from_acc, fee, nonce)
    SignedTx.sign_tx(spend_tx, from_acc_priv_key)
  end

  @doc """
  Adds balance to a given address (public key)
  """
  @spec transaction_in(ChainState.account(), integer()) :: ChainState.account()
  def transaction_in(account_state, value) do
    new_balance = account_state.balance + value
    Map.put(account_state, :balance, new_balance)
  end

  @doc """
  Deducts balance from a given address (public key)
  """
  @spec transaction_out(ChainState.account(), integer(), integer()) :: ChainState.account()
  def transaction_out(account_state, value, nonce) do
    account_state
    |> Map.put(:nonce, nonce)
    |> transaction_in(value)
  end
end
