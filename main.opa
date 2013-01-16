import stdlib.themes.bootstrap
import stdlib.web.client

type conclusion = {
  int id,
  string text,
}

type argument = {
  int id,
  string author,
  int conclusion_id,
  bool for_conclusion,
  string arg,
  list((int,int)) scores,
}

database arg {
  argument /args[{id}]
  conclusion /concs[{id}]
  /args[_]/for_conclusion = true
}

function arg_of_id(id) { ?/arg/args[{~id}] }
function conc_of_id(id) { ?/arg/concs[{~id}] }
function exnify(of_id, msg) {
  function (id) {
    match (of_id(id)) {
    | {none}: error(msg)
    | {some:x}: x
    }
  }
}
conc_of_id_exn = exnify(conc_of_id, "conc of id")
arg_of_id_exn = exnify(arg_of_id, "arg of id")

function display_list(rowf,l) {
  match (l) {
    case []: <p><em>(empty)</em></p>
    case l:
      <ul> {Xhtml.createFragment(List.map(rowf,l))} </ul>
  }
}

function args_for_conc(conc_id) {
  dbset(argument,_) args = /arg/args[conclusion_id == conc_id];
  list_of_dbset(args)
}

function arg_score(a) {
  sum = List.fold_left(
    function(acc, (pre,post)) {
      s = max(0, post - pre);
      s + acc
    }, 0, a.scores
  );
  len = List.length(a.scores);
  if (len == 0) 0 else (sum / len)
}

function arg_summary(arg) {
  score = arg_score(arg);
  pre = "({score}) "
  match (String.get_prefix(12, arg.arg)) {
    | {none} -> pre ^ arg.arg
    | {some:p} -> pre ^ p ^ "..."
  }
}

function get_args(conc_id) {
  dbset(argument,_) fors =
    /arg/args[conclusion_id == conc_id, for_conclusion == true];
  dbset(argument,_) againsts =
    /arg/args[conclusion_id == conc_id, for_conclusion == false];
  (list_of_dbset(fors), list_of_dbset(againsts))
}

function argument_exists(id) {
  match (arg_of_id(id)) {
    | {none}: false | {some:_}: true
  }
}

function conc_exists(id) {
  match (conc_of_id(id)) {
    | {none}: false | {some:_}: true
  }
}

function save_arg(argument) {
  /arg/args[{id:argument.id}] <- argument
}

function save_conc(conc) {
  /arg/concs[{id:conc.id}] <- conc
}

function new_conc(text) {
  id = Ids.next("conclusion", conc_exists);
  conc = { ~id, ~text };
  save_conc(conc);
  conc
}

function new_arg(author, conclusion_id,
                      for_conclusion, arg) {
  id = Ids.next("argument", argument_exists);
  argument = {
    ~id, ~author, ~conclusion_id,
    ~for_conclusion, ~arg, scores:[]
  };
  save_arg(argument)
}

function list_of_dbset(dbset) {
  it = DbSet.iterator(dbset);
  Iter.to_list(it);
}

function all_concs() {
  dbset(conclusion,_) concs = /arg/concs[];
  list_of_dbset(concs);
}

function page_new_arg(conc_id) {
  conc = conc_of_id_exn(conc_id);
  <>
   <div id=#status/>
   <h3>conclusion:</h3>
   <p>{conc.text}</p>
   <form options:onsubmit="prevent_default">
    <input type="radio" id=#for_true name="for" value="true"
      checked="true"/>
      <strong>for</strong> the conclusion <br/>
    <input type="radio" id=#for_false name="for" value="false"/>
      <strong>against</strong> the conclusion <br/>
    <br/>
    your email (kept private):
     <input id=#author type="text" maxlength="100"/>
    <br/>
    your argument: <br/>
      <textarea id=#arg rows="10" cols="80"/>
    <button onclick={function(_) { submit_new_arg(conc_id) }}
      type="submit">submit new argument</button>
   </form>
  </>
}

function submit_new_arg(conc_id) {
  author = Dom.get_value(#author);
  for_conc = match (List.find(Dom.is_checked,
    [#for_true, #for_false])) {
    | {none} -> false
    | {some:x} -> Dom.get_id(x) == "for_true"
  };
  arg = Dom.get_value(#arg);
  wc = String.word_count(arg);
  if (wc > 100) {
    render_err("word count " ^ Int.to_string(wc) ^ " too high")
  } else {
    new_arg(author, conc_id, for_conc, arg);
    render_ok("saved")
  }
}

function render_err(msg) {
  html = <div class="alert alert-error">{msg}</div>;
  Dom.transform([#status = html])
}

function render_ok(msg) {
  html = <div class="alert alert-success">{msg}</div>;
  Dom.transform([#status = html])
}

function evaluator(tag, next) {
  //conc = conc_of_id_exn(arg.conclusion_id);
  <>
   <p>How well do you agree with this conclusion?</p>
   <form options:onsubmit="prevent_default">
    <table>
     <tr>
      <td> <input type="radio" id=#{tag ^ "_strd"} name="eval"/> </td>
      <td> <input type="radio" id=#{tag ^ "_somd"} name="eval"/> </td>
      <td> <input type="radio" id=#{tag ^ "_nand"} name="eval"/> </td>
      <td> <input type="radio" id=#{tag ^ "_soma"} name="eval"/> </td>
      <td> <input type="radio" id=#{tag ^ "_stra"} name="eval"/> </td>
     </tr>
     <tr>
      <td> strongly disagree </td>
      <td> somewhat disagree </td>
      <td> neither agree nor disagree </td>
      <td> somewhat agree </td>
      <td> strongly agree </td>
     </tr>
    </table>
    <button onclick={function(_) { next() }} type="submit">go</button>
   </form>
  </>
}

function get_score(tag) {
  tagged_ids =
    List.map(
      function(x) { #{tag ^ "_" ^ x} },
        ["strd","somd","nand","soma","stra"]
    );
  match (List.find(Dom.is_checked, tagged_ids)) {
    | {none} -> {none}
    | {some:x} -> {
      id = Dom.get_id(x);
      match (String.get_suffix(4,id)) {
        | {none} -> { render_err("unknown radio id '{id}'"); {none} }
        | {some:suf} -> match (suf) {
          | "strd" -> {some:-2}
          | "somd" -> {some:-1}
          | "nand" -> {some:0}
          | "soma" -> {some:1}
          | "stra" -> {some:2}
          | _ -> { render_err("unknown radio id '{id}'"); {none} }
          }
        }
      }
  }
}

function eval_arg_step2(a) {
  match (get_score("pre")) {
  | {none} -> render_err("choose, silly!")
  | {some:initial} -> {
      html =
       <>
        <p>Now consider this argument
          <strong>{foragainst(a)}</strong> the conclusion:</p>
        <p class="well">{a.arg}</p>
        <button onclick={function(_) {eval_arg_step3(a, initial)}}
          >done reading</button>
       </>;
      #argument = html;
    }
  }
}

function eval_arg_step3(arg, initial) {
  #posteval =
    <>
     <p>In light of the argument you just read, </p>
     {evaluator("post", {function() { eval_arg_step4(arg, initial) }})}
    </>
}

function eval_arg_step4(arg, initial) {
  match (get_score("post")) {
  | {none} -> render_err("choose, silly!")
  | {some:final} -> {
    score = (initial, final);
    save_arg({arg with scores:[score|arg.scores]});
    render_ok("thanks for playing!")
    }
  }
}

function page_eval_arg(arg_id) {
  arg = arg_of_id_exn(arg_id);
  conc_id = arg.conclusion_id;
  conc = conc_of_id_exn(conc_id);
  <>
    <div id=#status/>
    <div id=#conclusion>
     Conclusion: <p class="well">{conc.text}</p>
    </div>
    <div id=#evaluator>
     {evaluator("pre", {function() { eval_arg_step2(arg) }})}
    </div>
    <div id=#argument/>
    <div id=#posteval/>
  </>
}

function choose_random_arg(conc_id) {
  List.random_elt(args_for_conc(conc_id));
}

function page_eval_conc(conc_id) {
  args = args_for_conc(conc_id);
  function row(arg) {
    <li>
     <a href="/arg/{arg.id}">{arg_summary(arg)}</a>
    </li>
  }
  <>
    <div id=#status/>
    <h3>choose an argument to evaluate</h3>
    {display_list(row,args)}
  </>
}

function page_conc(id) {
  conc = conc_of_id_exn(id);
  (fors, againsts) = get_args(id);
  function arg_row(arg) {
    <li><a href="/arg/{arg.id}">{arg_summary(arg)}</a></li>
  }
  <div>
    <h2>Conclusion: </h2>
    <p class="well">{conc.text}</p>
    <h2>arguments <strong>for</strong>:</h2>
    {display_list(arg_row,fors)}
    <h2>arguments <strong>against</strong>:</h2>
    {display_list(arg_row,againsts)}
    <br/>
    <a class="btn" href="/newarg/{id}"
      >new argument about this conclusion</a>
  </div>
}

function page_new_conc() {
  <>
   <div id=#status/>
   <h3>new conclusion</h3>
   <form options:onsubmit="prevent_default">
    <input type="text" id=#conc maxlength="150"/>
    <button onclick={function(_) { submit_new_conc() }}
      >submit new conclusion</button>
   </form>
  </>
}

function submit_new_conc() {
  conc = Dom.get_value(#conc);
  conc = new_conc(conc);
  render_ok(
    <>success: <a href="/conc/{conc.id}">go to new conclusion</a></>
  )
}

function foragainst(a) {
  if (a.for_conclusion) "for" else "against";
}

function index() {
  function concrow(conc) {
    <li>
     <a href="/conc/{conc.id}">{conc.text}</a>
    </li>
  }
  <>
   <h2>conclusions:</h2>
   {display_list(concrow,all_concs())}
   <hr/>
   <a class="btn" href="/newconc">propose a new conclusion</a><br/>
   <a class="btn" href="/evalrandom">evaluate a random argument</a>
  </>
}

function makepage(title, html) {
  fullh =
   <div class="container">
    <div class="row">
     <div class="span7 offset1">
      <p><a href="/">overview</a>
        | <a href="/newconc">new conclusion</a></p>
      <hr/>
      {html}
     </div>
    </div>
   </div>;
  Resource.page(title, fullh)
}

Server.start(Server.http, { dispatch:
  (function (x) { match (x) {
  | {path:[] ...} -> makepage("index", index())
  | {path:["arg", id] ...} ->
    makepage("evaluate an argument",
      page_eval_arg(Int.of_string(id)))
  | {path:["newarg", id] ...} ->
    makepage("new argument", page_new_arg(Int.of_string(id)))
  | {path:["newconc"] ...} ->
    makepage("new conclusion", page_new_conc())
  | {path:["eval", id] ...} ->
    makepage("evaluate arguments", page_eval_conc(Int.of_string(id)))
  | {path:["conc", id] ...} ->
    makepage("conclusion", page_conc(Int.of_string(id)))
  | {path:_ ...} ->
    makepage("huh?", <>huh?</>)
  }})}
)
