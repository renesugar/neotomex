defmodule Neotomex.PEGTest do
  use ExUnit.Case
  require Logger

  test "validate the PEG grammar" do
    assert Neotomex.Grammar.validate(Neotomex.PEG.grammar) == :ok
  end

  test "match PEG grammar using neotomex PEG metagrammar" do
    assert {:ok, _, ""} = Neotomex.PEG.match("A <- a")
    assert {:ok, _, ""} = Neotomex.PEG.match("A1 <- abra")
    assert {:ok, _, ""} = Neotomex.PEG.match("A <- 'a'")
    assert {:ok, _, ""} = Neotomex.PEG.match("A <- B 'a'\rB <- 'b'")
    assert {:ok, _, ""} = Neotomex.PEG.match("A <- [a-zA-Z]")
    assert {:ok, _, ""} = Neotomex.PEG.match("A <- [a-zA-Z0-9]")
  end

  test "parse PEG grammar using neotomex PEG metagrammar" do
    assert Neotomex.PEG.parse("a <- 'a'") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:terminal, "a"}})}
    assert Neotomex.PEG.parse("a <- !'a'") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:not, {:terminal, "a"}}})}
    assert Neotomex.PEG.parse("a <- &'a'") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:and, {:terminal, "a"}}})}
    assert Neotomex.PEG.parse("a <- 'a'+") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:one_or_more, {:terminal, "a"}}})}
    assert Neotomex.PEG.parse("a <- 'a'*") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:zero_or_more, {:terminal, "a"}}})}
    assert Neotomex.PEG.parse("a <- 'a'*") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:zero_or_more, {:terminal, "a"}}})}

    assert Neotomex.PEG.parse("a <- a") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:nonterminal, :a}})}

    assert Neotomex.PEG.parse("a <- a / b") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:priority, [{:nonterminal, :a},
                                                       {:nonterminal, :b}]}})}
    assert Neotomex.PEG.parse("a <- a b") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:sequence, [{:nonterminal, :a},
                                                       {:nonterminal, :b}]}})}
    assert Neotomex.PEG.parse("a <- (a b)") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:sequence, [{:nonterminal, :a},
                                                       {:nonterminal, :b}]}})}

    assert Neotomex.PEG.parse("a <- a\nb <- b") ==
      {:ok, Neotomex.Grammar.new(:a, %{a: {:nonterminal, :a},
                                       b: {:nonterminal, :b}})}
  end

  test "all together now: parse a PEG grammar, and use it to parse" do
    assert {:ok, grammar} = Neotomex.PEG.parse("a <- 'a'+")
    assert Neotomex.Grammar.validate(grammar) == :ok
    assert Neotomex.Grammar.parse(grammar, "")   == :mismatch
    assert Neotomex.Grammar.parse(grammar, "a")  == {:ok, ["a"], ""}
    assert Neotomex.Grammar.parse(grammar, "aa") == {:ok, ["a", "a"], ""}
  end
end