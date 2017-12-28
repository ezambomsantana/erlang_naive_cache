-module(naive_cache_app).

-type ttl() :: integer().
-type reason() :: list().

-behaviour(gen_server).

-export([start/0, stop/0, start_link/1, init/1, eval/2, handle_cast/2, handle_call/3, terminate/1]).

-spec start() -> {ok, _} | {error, term()}.
start() ->
  ok.

-spec stop() -> ok.
stop() ->
  application:stop(naive_cache_app).

-spec start_link(atom()) -> gen:start_ret().
start_link(Name) ->
   {ok, Pid} = gen_server:start_link({local, Name}, ?MODULE, [], []),
   put(pid_server, Pid),
   {ok, Pid}.

init([]) -> {ok, []}.

terminate(normal) ->
   ok.

-spec get_timestamp() -> integer().
get_timestamp() ->
  {Mega, Sec, Micro} = os:timestamp(),
(Mega*1000000 + Sec)*1000 + round(Micro/1000).

%naive_cache_app:eval({lists, reverse,[[1,2,3,4,5]]}, 5000).

-spec eval(mfa(), ttl()) -> {ok, any()} | {error, reason()}.
eval(Mfa, Ttl) -> 
   Pid = get(pid_server),
   gen_server:call(Pid, {execute, Mfa, Ttl, Pid}).

handle_call({execute, Mfa, Ttl, Pid}, _From, State) ->
   Value = get( Mfa ),
   case Value of 
      undefined ->
         io:format("not in the cache, running the function!"),
         gen_server:cast(Pid, {execute, Mfa, Ttl}), 
         put(Mfa, waiting),
         {reply, {ok, waiting}, State };
         
      waiting ->      
         io:format("function is running, please wait!"),
         {reply, {ok, not_finished}, State };
      _ ->
         FuncValue = element(1, Value),
         FuncTtl = element(2, Value),
         RunTimestamp = element(3, Value),
         CurrentTimestamp = get_timestamp(),

         case CurrentTimestamp - RunTimestamp > FuncTtl of
             true ->
                 io:format("value found in the cache but expired, running the fuction!"),
                 gen_server:cast(Pid, {execute, Mfa, Ttl}),
                 put(Mfa, waiting),
                 {reply, {ok, waiting}, State };
             false ->
                 io:format("value found in the cache, returning the value!"),
                 {reply, {ok, FuncValue}, State }
         end
   end. 
   
handle_cast({execute, Mfa, Ttl}, State) ->
   try
      FuncValue = erlang:apply(element(1, Mfa), element(2, Mfa), element(3, Mfa)),
      put(Mfa, { FuncValue , Ttl, get_timestamp() }),
      {noreply, State }
    catch
      _:Error ->
         put(Mfa, { {error, Error}, Ttl, get_timestamp() }),
         {noreply, State }
    end.

%-spec get_result(any()) -> any().
%get_result(Value) -> Value.	
