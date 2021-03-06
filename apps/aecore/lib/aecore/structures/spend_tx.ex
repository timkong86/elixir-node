defmodule Aecore.Structures.SpendTx do
  @moduledoc """
  Aecore structure of a transaction data.
  """

  @behaviour Aecore.Structures.Transaction
  alias Aecore.Structures.SpendTx
  alias Aecore.Structures.Account
  alias Aecore.Chain.ChainState
  alias Aecore.Wallet
  alias Aecore.Structures.Account

  require Logger

  @typedoc "Expected structure for the Spend Transaction"
  @type payload :: %{
          to_acc: Wallet.pubkey(),
          value: non_neg_integer()
        }

  @typedoc "Reason for the error"
  @type reason :: String.t()

  @typedoc "Structure that holds specific transaction info in the chainstate.
  In the case of SpendTx we don't have a subdomain chainstate."
  @type tx_type_state() :: %{}

  @typedoc "Structure of the Spend Transaction type"
  @type t :: %SpendTx{
          to_acc: Wallet.pubkey(),
          value: non_neg_integer()
        }

  @doc """
  Definition of Aecore SpendTx structure

  ## Parameters
  - to_acc: To account is the public address of the account receiving the transaction
  - value: The amount of tokens send through the transaction
  """
  defstruct [:to_acc, :value]
  use ExConstructor

  # Callbacks

  @spec init(payload()) :: SpendTx.t()
  def init(%{to_acc: to_acc, value: value} = _payload) do
    %SpendTx{to_acc: to_acc, value: value}
  end

  @doc """
  Checks wether the value that is send is not a negative number
  """
  @spec is_valid?(SpendTx.t()) :: boolean()
  def is_valid?(%SpendTx{value: value}) do
    if value >= 0 do
      true
    else
      Logger.error("Value cannot be a negative number")
      false
    end
  end

  @doc """
  Makes a rewarding SpendTx (coinbase tx) for the miner that mined the next block
  """
  @spec reward(SpendTx.t(), integer(), ChainState.account()) :: ChainState.accounts()
  def reward(%SpendTx{} = tx, _block_height, account_state) do
    Account.transaction_in(account_state, tx.value)
  end

  @doc """
  Changes the account state (balance) of the sender and receiver.
  """
  @spec process_chainstate!(
          SpendTx.t(),
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          ChainState.account(),
          tx_type_state()
        ) :: {ChainState.accounts(), tx_type_state()}
  def process_chainstate!(%SpendTx{} = tx, from_acc, fee, nonce, accounts, %{}) do
    case preprocess_check(tx, accounts[from_acc], fee, nonce, %{}) do
      :ok ->
        new_from_account_state =
          accounts[from_acc]
          |> deduct_fee(fee)
          |> Account.transaction_out(tx.value * -1, nonce)

        new_accounts = Map.put(accounts, from_acc, new_from_account_state)

        to_acc = Map.get(accounts, tx.to_acc, Account.empty())
        new_to_account_state = Account.transaction_in(to_acc, tx.value)
        {Map.put(new_accounts, tx.to_acc, new_to_account_state), %{}}

      {:error, _reason} = err ->
        throw(err)
    end
  end

  @doc """
  Checks whether all the data is valid according to the SpendTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check(
          SpendTx.t(),
          ChainState.account(),
          non_neg_integer(),
          non_neg_integer(),
          tx_type_state()
        ) :: :ok | {:error, String.t()}
  def preprocess_check(tx, account_state, fee, nonce, %{}) do
    cond do
      account_state.balance - (fee + tx.value) < 0 ->
        {:error, "Negative balance"}

      account_state.nonce >= nonce ->
        {:error, "Nonce too small"}

      true ->
        :ok
    end
  end

  @spec deduct_fee(ChainState.account(), non_neg_integer()) :: ChainState.account()
  def deduct_fee(account_state, fee) do
    new_balance = account_state.balance - fee
    Map.put(account_state, :balance, new_balance)
  end
end
