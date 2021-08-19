defmodule Bank.Core.Router do
  use Commanded.Commands.Router

  alias Bank.Core.Commands

  dispatch(
    [
      Commands.DepositMoney,
      Commands.WithdrawMoney
    ],
    to: Bank.Core.Accounts.Account,
    identity: :user_id,
    identity_prefix: "user_account-"
  )
end
