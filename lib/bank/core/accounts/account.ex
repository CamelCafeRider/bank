defmodule Bank.Core.Accounts.Account do
  alias Bank.Core.Commands.{
    DepositMoney,
    WithdrawMoney,
    SendMoneyToAccount,
    ReceiveMoneyFromAccount,
    FailMoneyTransfer
  }

  alias Bank.Core.Events.{
    MoneyDeposited,
    MoneyWithdrawn,
    JournalEntryCreated,
    AccountOpened,
    MoneyReceivedFromAccount,
    MoneyReceivedFromAccountFailed,
    MoneySendToAccount,
    MoneyTransferFailed
  }

  alias Bank.Core.Accounts.Account

  @type t() :: %__MODULE__{id: binary(), balance: integer()}
  defstruct [:id, balance: 0]

  def execute(%Account{id: nil}, %DepositMoney{} = cmd) do
    [
      %AccountOpened{
        account_id: cmd.account_id
      },
      %MoneyDeposited{
        account_id: cmd.account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        debit: %{"100" => cmd.amount},
        credit: %{"#{cmd.account_id}" => cmd.amount}
      }
    ]
  end

  def execute(%Account{id: nil}, %ReceiveMoneyFromAccount{} = cmd) do
    %MoneyReceivedFromAccountFailed{
      transaction_id: cmd.transaction_id,
      from_account_id: cmd.from_account_id,
      to_account_id: cmd.to_account_id,
      amount: cmd.amount
    }
  end

  def execute(%Account{id: nil}, _cmd), do: {:error, :not_found}

  def execute(%Account{}, %DepositMoney{} = cmd) do
    [
      %MoneyDeposited{
        account_id: cmd.account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        debit: %{"100" => cmd.amount},
        credit: %{"#{cmd.account_id}" => cmd.amount}
      }
    ]
  end

  def execute(%Account{balance: balance}, %WithdrawMoney{amount: amount})
      when balance - amount < 0 do
    {:error, :insufficient_balance}
  end

  def execute(%Account{}, %WithdrawMoney{} = cmd) do
    [
      %MoneyWithdrawn{
        account_id: cmd.account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        debit: %{"#{cmd.account_id}" => cmd.amount},
        credit: %{"100" => cmd.amount}
      }
    ]
  end

  def execute(%Account{balance: balance}, %SendMoneyToAccount{amount: amount})
      when balance - amount < 0 do
    {:error, :insufficient_balance}
  end

  def execute(%Account{} = state, %SendMoneyToAccount{} = cmd) do
    transaction_id = Ecto.UUID.generate()

    [
      %MoneySendToAccount{
        transaction_id: transaction_id,
        from_account_id: state.id,
        to_account_id: cmd.to_account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        debit: %{"#{state.id}" => cmd.amount},
        credit: %{"#{transaction_id}" => cmd.amount}
      }
    ]
  end

  def execute(%Account{} = state, %ReceiveMoneyFromAccount{} = cmd) do
    [
      %MoneyReceivedFromAccount{
        transaction_id: cmd.transaction_id,
        from_account_id: state.id,
        to_account_id: cmd.to_account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        credit: %{"#{cmd.to_account_id}" => cmd.amount},
        debit: %{"#{cmd.transaction_id}" => cmd.amount}
      }
    ]
  end

  def execute(%Account{} = state, %FailMoneyTransfer{} = cmd) do
    [
      %MoneyTransferFailed{
        transaction_id: cmd.transaction_id,
        from_account_id: state.id,
        to_account_id: cmd.to_account_id,
        amount: cmd.amount
      },
      %JournalEntryCreated{
        journal_entry_uuid: Ecto.UUID.generate(),
        credit: %{"#{state.id}" => cmd.amount},
        debit: %{"#{cmd.transaction_id}" => cmd.amount}
      }
    ]
  end

  def apply(state, %AccountOpened{} = evt) do
    %{state | id: evt.account_id}
  end

  def apply(state, %MoneyDeposited{} = evt) do
    %{state | balance: state.balance + evt.amount}
  end

  def apply(state, %MoneyWithdrawn{} = evt) do
    %{state | balance: state.balance - evt.amount}
  end

  def apply(state, %MoneySendToAccount{} = evt) do
    %{state | balance: state.balance - evt.amount}
  end

  def apply(state, %MoneyReceivedFromAccount{} = evt) do
    %{state | balance: state.balance + evt.amount}
  end

  def apply(state, %MoneyTransferFailed{} = evt) do
    %{state | balance: state.balance + evt.amount}
  end

  def apply(state, %JournalEntryCreated{}), do: state
  def apply(state, %MoneyReceivedFromAccountFailed{}), do: state
end
