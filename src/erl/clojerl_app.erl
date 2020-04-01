-module(clojerl_app).

-behavior(application).

-export([unstick/0]).

-export([start/2, stop/1]).

-define(APP, clojerl).
-define(STICKY_MODULES, ['clojure.core']).

-spec start(any(), any()) -> {ok, pid()} | {ok, pid(), any()} | {error, any()}.
start(_Type, _Args) ->
  {ok, Pid} = clojerl_sup:start_link(),
  ok = stacktrace_depth(),
  ok = io_options(),
  ok = stick(),
  ok = init(),
  {ok, Pid}.

-spec stop(any()) -> ok.
stop(_State) -> ok.

%%==============================================================================
%% Internal functions
%%==============================================================================

-spec init() -> ok.
init() ->
  CljeUserSym = clj_rt:symbol(<<"clje.user">>),
  'clojure.core':'in-ns'(CljeUserSym),
  %% This will not be available during bootstrap
  case erlang:function_exported('clojure.core', refer, 2) of
    true ->
      ClojureCoreSym = clj_rt:symbol(<<"clojure.core">>),
      'clojure.core':'refer'(ClojureCoreSym, []),

      %% Maybe load user.clje script
      clj_rt:load_script(<<"user.clje">>, false),

      ClojureCoreServerSym = clj_rt:symbol(<<"clojure.core.server">>),
      'clojure.core':require([ClojureCoreServerSym]),
      'clojure.core.server':'start-servers'(clj_utils:env_vars()),
      ok;
    false ->
      ok
  end.

-spec stacktrace_depth() -> ok.
stacktrace_depth() ->
  StacktraceDepth = application:get_env(?APP, backtrace_depth, 20),
  erlang:system_flag(backtrace_depth, StacktraceDepth),
  ok.

-spec io_options() -> ok.
io_options() ->
  %% Ensure encoding is unicode
  IoOpts = [{binary, true}, {encoding, unicode}],
  ok = io:setopts(IoOpts).

%% Coverage analysis fails if the directory is sticky
-ifdef(COVER).
-spec stick() -> ok.
stick() -> ok.
-else.
-spec stick() -> ok.
stick() ->
  [code:stick_mod(M) || M <- ?STICKY_MODULES],
  ok.
-endif.

-spec unstick() -> ok.
unstick() ->
  [code:unstick_mod(M) || M <- ?STICKY_MODULES],
  ok.
