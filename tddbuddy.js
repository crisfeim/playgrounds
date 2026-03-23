// tasks.json
[
  {
    "label": "Run Tests",
    "command": "deno test ./core/tests",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  },
  {
    "label": "Run E2E Tests",
    "command": "deno test ./core/e2eTests --allow-net",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  },
  {
    "label": "Run Integration Tests",
    "command": "deno test ./core/integrationTests --allow-net",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  },
  {
    "label": "Run All Tests",
    "command": "deno test --allow-net",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  },
  {
    "label": "Build Core",
    "command": "esbuild ./core/entrypoint.ts --bundle --outfile=./ui/_imports/core.js --platform=browser --format=iife --global-name=CodeGenCore",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  },
  {
    "label": "Watch UI",
    "command": "node ./build.js",
    "use_new_terminal": false,
    "allow_concurrent_runs": false,
    "reveal": "always",
    "hide": "never",
    "shell": "system",
    "show_summary": true,
    "show_output": true,
    "tags": []
  }
]

// _entrypoint.ts
import { makeReactiveViewModel , ViewModel, Status} from "./viewModel.ts";

import { OllamaClient } from "./ollamaclient.ts"
import { GeminiClient } from "./geminiclient.ts"
import { EvalRunner } from "./evalrunner.ts"

export const ollamaViewModel: (maxIterations: number) => ViewModel = (maxIterations) => {
  const client = new OllamaClient();
  const runner = new EvalRunner();
  return makeReactiveViewModel(client, runner, maxIterations);
};

export const geminiViewModel: (apiKey: string, maxIterations: number) => ViewModel = (apiKey, maxIterations) => {
  const client = new GeminiClient(apiKey);
  const runner = new EvalRunner();
  return makeReactiveViewModel(client, runner, maxIterations);
};

import { LLM7Client } from "./llm7client.ts";
export const llm7ViewModel: (maxIterations: number) => ViewModel = (maxIterations) => {
  const client = new LLM7Client();
  const runner = new EvalRunner();
  return makeReactiveViewModel(client, runner, maxIterations);
};

import { Client, Runner, RunResult } from "./coordinator.ts";

export const fakeClientViewModel: () => ViewModel = () => {
  class FakeClient implements Client {
    private base = [1, 2, 3];
    private ids = [...this.base];

    async send(): Promise<string> {
      if (this.ids.length === 0) {
        this.ids = [...this.base];
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
      return `Generated code ${this.ids.shift()}`;
    }
  }

  class FakeRunner implements Runner {
    private base = [false, false, true];
    private results = [...this.base];

    run(code: string): RunResult {
      if (this.results.length === 0) {
        this.results = [...this.base];
      }
      return { isValid: this.results.shift()! };
    }
  }

  const client = new FakeClient();
  const runner = new FakeRunner();
  return makeReactiveViewModel(client, runner, 3);
};


// coordinator.ts
import { Iterator } from "./iterator.ts";

export type Message = {
  role: "user" | "system" | "assistant";
  content: string
}

export interface Client {
   send(messages: Message[]): Promise<string>;
}

export type RunResult = {
  stdErr?: string;
  isValid: boolean;
}
export interface Runner {
  run(code: string): RunResult
}

export class Coordinator {
  constructor(private client: Client, private runner: Runner, private iterator: Iterator) {
    this.client = client
    this.runner = runner
    this.iterator = iterator
  }

  async generate(systemPrompt: string, specs: string, maxIterations: number): Promise<Coordinator.Result> {
    let previousStderr: string | undefined
    return await this.iterator.iterate(
      maxIterations,
      async () => await this.generateCodeFromSpecsWithPreviousFeedback(systemPrompt, specs, previousStderr),
      (result) => { previousStderr = result.stdErr;  return result.isValid })
  }

  async generateCodeFromSpecsWithPreviousFeedback(systemPrompt: string, specs: string, previousStderr?: string): Promise<Coordinator.Result> {
    const systemPromptMessage: Message = { role: "system", content: systemPrompt }
    const userMessage: Message = { role: "user", content: specs }
    let messages = [systemPromptMessage, userMessage]
    if (previousStderr) {
      messages.push({ role: "assistant", content: previousStderr })
    }
    const generated = await this.client.send(messages)
    const processed = generated
       .replace(/^```(?:\w+)?\s*/m, '')
       .replace(/```$/, '')
    const concatenated = `${generated}\n${specs}`
    const runResult = this.runner.run(concatenated)
    return { generatedCode: generated, stdErr: runResult.stdErr, isValid: runResult.isValid }
  }

  // @TODO: remove this method
  async generateCodeFromSpecs(systemPrompt: string, specs: string): Promise<Coordinator.Result> {
    const systemPromptMessage: Message = { role: "system", content: systemPrompt }
    const userMessage: Message = { role: "user", content: specs }
    const generated = await this.client.send([systemPromptMessage, userMessage])
    const concatenated = `${specs}\n${generated}`
    const runResult = this.runner.run(concatenated)
    return { generatedCode: generated, isValid: runResult.isValid }
  }
}

export namespace Coordinator {
  export type Result = {
    generatedCode: string;
    stdErr?: string;
    isValid: boolean;
  };
}


// e2eTests/geminiclient.e2e.test.ts
import { Message } from "../coordinator.ts";
import { assertStringIncludes } from "https://deno.land/std/assert/mod.ts";
import { GeminiClient } from "../geminiclient.ts";
import { gemini_api_key } from "../secret_api_keys.ts";

Deno.test("GeminiClient: send", async () => {
  const client = new GeminiClient(gemini_api_key);
  const messages: Message[] = [
    { role: "system", content: "You always respond with a single word: hi" },
    { role: "user", content: "Hello" },
  ];

  const response = await client.send(messages);

  assertStringIncludes(response.toLocaleLowerCase(), "hi");
});


// e2eTests/ollamaclient.e2e.test.ts
import { Message } from "../coordinator.ts";
import { assertStringIncludes } from "https://deno.land/std/assert/mod.ts";
import { OllamaClient } from "../ollamaclient.ts";

Deno.test("OllamaClient: send", async () => {
  const client = new OllamaClient();
  const messages: Message[] = [
    { role: "system", content: "You always respond with a single word: hi" },
    { role: "user", content: "Hello" },
  ];

  const response = await client.send(messages);

  assertStringIncludes(response.toLowerCase(), "hi");
});


// entrypoint.ts
import { ollamaViewModel, geminiViewModel, fakeClientViewModel, llm7ViewModel } from "./_entrypoint";

this.ollamaViewModel = ollamaViewModel;
this.geminiViewModel = geminiViewModel;
this.fakeClientViewModel = fakeClientViewModel;
this.llm7ViewModel = llm7ViewModel;


// evalrunner.ts
import { Runner, RunResult } from "./coordinator.ts";

export class EvalRunner implements Runner {

  run(code: string): RunResult {
    const assertHelpers = `
       function assertEqual(actual, expected) {
         if (actual !== expected) {
           throw new Error(\`Assertion failed: expected \${expected}, but got \${actual}\`);
         }
       }
     `;

    try {
      eval(assertHelpers + "\n" + code);
      return { isValid: true };
    } catch (error) {
      return {
        isValid: false,
        stdErr: String(error),
      };
    }
  }
}


// geminiclient.ts
import { Client, Message } from "./coordinator.ts";
export class GeminiClient implements Client {
  constructor(private apiKey: string) {}

  async send(messages: Message[]): Promise<string> {
    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${this.apiKey}`;

    const mapped = messages.map(({ role, content }) => ({
      role: role === "system" ? "model" : role,
      parts: [{ text: content }],
    }));

    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: mapped,
        generationConfig: {
          stopSequences: [],
        },
      }),
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(`GeminiClient: API error: ${err.error.message}`);
    }

    const data = await res.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  }
}


// iterator.ts
export class Iterator {
  async iterate<T>(nTimes: number, action: () => Promise<T>, until: (value: T) => boolean): Promise<T> {
    let currentIteration = 0;
    let result: T
    while (currentIteration < nTimes) {
      result = await action();
      if (until(result)) { return result }
      currentIteration++;
    }
    return result!
  }
}


// llm7client.ts
import { Client, Message } from "./coordinator.ts";

export class LLM7Client implements Client {
  private readonly model = "gpt-3.5-turbo";
  private readonly url = "https://api.llm7.io/v1/chat/completions";

  async send(messages: Message[]): Promise<string> {
    const body = {
      model: this.model,
      messages: messages,
      stream: false,
    };

    const response = await fetch(this.url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`LLM7Client: HTTP error ${response.status}`);
    }

    const data = await response.json();

    if (!data?.choices?.[0]?.message?.content) {
      throw new Error("LLM7Client: Invalid response shape");
    }

    return data.choices[0].message.content;
  }
}


// ollamaclient.ts
import { Client, Message } from "./coordinator.ts";
export class OllamaClient implements Client {
  private readonly model = "llama3.2";
  private readonly url = "http://localhost:11434/api/chat";

  async send(messages: Message[]): Promise<string> {
    const body = {
      model: this.model,
      messages: messages,
      stream: false,
    };

    const response = await fetch(this.url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`OllamaClient: HTTP error ${response.status}`);
    }

    const data = await response.json();

    if (!data?.message?.content) {
      throw new Error("OllamaClient: Invalid response shape");
    }

    return data.message.content;
  }
}


// tests/contextual-generation.test.ts
import { assertEquals, assertRejects } from "https://deno.land/std/assert/mod.ts";
import { Coordinator, Client, Runner, RunResult, Message } from "../coordinator.ts";
import { Iterator } from "../iterator.ts";

Deno.test("generate appends run feedback as assistant message on each iteration", async () => {

  class AlywaysFailingRunner implements Runner {
    errorMessage: string
    constructor(errorMessage: string) {this.errorMessage = errorMessage}
    run(code: string): RunResult { return {
      stdErr: this.errorMessage,
      isValid: false
    } }
  }

  class ClientSpy implements Client {
    calls: Message[][] = []
    async send(messages: Message[]): Promise<string> {
      this.calls.push(messages)
      return "any generated code"
    }
  }

 const anyRunErrorMessage = "any run error message"
 const alwaysFailingRunner = new AlywaysFailingRunner(anyRunErrorMessage)
 const client = new ClientSpy()
 const iterator = new Iterator()
 const sut = new Coordinator(client, alwaysFailingRunner, iterator)
 const result = await sut.generate("any system prompt", "any specs", 2)

 assertEquals(client.calls.length, 2)

 assertEquals(client.calls[0], [
   { role: "system", content: "any system prompt" },
   { role: "user", content: "any specs" },
 ]);

 assertEquals(client.calls[1], [
   { role: "system", content: "any system prompt" },
   { role: "user", content: "any specs" },
   { role: "assistant", content: anyRunErrorMessage }
 ]);
})


// tests/evalrunner.test.ts
import { EvalRunner } from "../evalrunner.ts";
import { assert, assertEquals } from "https://deno.land/std/assert/mod.ts";

Deno.test("EvalRunner fails on invalid syntax code", () => {
  const runner = new EvalRunner();
  const result = runner.run("const = no;");
  assert(result.isValid === false);
  assert(typeof result.stdErr === "string");
});

Deno.test("EvalRunner assertEqual throws on different values", () => {
  const runner = new EvalRunner();
  const code = `
    class Adder {
      constructor(a, b) {
        this.result = a + b;
      }
    }

    function testAdder() {
      const sut = new Adder(1, 2);
      assertEqual(sut.result, 4);
    }

    testAdder();
  `
  const result = runner.run(code);
  assertEquals(result.stdErr, "Error: Assertion failed: expected 4, but got 3")
  assert(result.isValid === false);
});

Deno.test("EvalRunner assertEqual doesn't throw on equal values", () => {
  const runner = new EvalRunner();
  const code = `
    class Adder {
      constructor(a, b) {
        this.result = a + b;
      }
    }

    function testAdder() {
      const sut = new Adder(1, 2);
      assertEqual(sut.result, 3);
    }

    testAdder();
  `
  const result = runner.run(code);
  assert(result.isValid === true);
  assert(result.stdErr === undefined)
});


// tests/iterated-generation.test.ts
import { assertEquals, assertRejects } from "https://deno.land/std/assert/mod.ts";
import { Coordinator, Client, Runner, RunResult, Message } from "../coordinator.ts";
import { Iterator } from "../iterator.ts";

Deno.test("generate iterates N times on always invalid code", async () => {
  class RunnerStub implements Runner {
    constructor(private readonly result: RunResult) {this.result = result}
    run(code: string): RunResult {
      return this.result
    }
  }
  const client = new ClientStub("any code")
  const runner = new RunnerStub({ isValid: false })
  const iterator = new IteratorSpy()
  const sut = new Coordinator(client, runner, iterator)
  const result = await sut.generate("any system prompt","any specs", 5)
  assertEquals(iterator.iterations, 5)
})

Deno.test("generate iterates until valid code", async () => {
  class RunnerStub implements Runner {
    constructor(private readonly results: boolean[]) {}
    run(code: string): RunResult {
      return { isValid: this.results.shift()! }
    }
  }

  const client = new ClientStub("any code")
  const runner = new RunnerStub([false, false, false, true])
  const iterator = new IteratorSpy()
  const sut = new Coordinator(client, runner, iterator)
  const result = await sut.generate("any system prompt", "any specs", 5)
  assertEquals(iterator.iterations, 4)
})


// Mocks
class ClientStub implements Client {
  constructor(private readonly code: string) {}
  async send(messages: Message[]): Promise<string> {
    return this.code
  }
}

export class IteratorSpy extends Iterator {
  public iterations = 0;

  override async iterate<T>(
    nTimes: number,
    action: () => Promise<T>,
    until: (value: T) => boolean
  ): Promise<T> {
    this.iterations = 0;

    return await super.iterate(
      nTimes,
      async () => {
        this.iterations++;
        return await action();
      },
      until
    );
  }
}


// tests/iterator.test.ts
import {assertEquals} from "https://deno.land/std/assert/mod.ts";
import { Iterator } from "../iterator.ts";

Deno.test("iterates N times if condition is never fullfilled", async () => {
  const sut = new Iterator()
  const maxIterations = 5
  let currentIteration = 0
  const action = async () => {
      currentIteration++;
      return "hello world";
    };
  const neverFullfilledCondition = (anyResult: string) => false
  const result = await sut.iterate(maxIterations, action, neverFullfilledCondition)
  assertEquals(currentIteration, maxIterations)
});

Deno.test("Iterates until condition is fullfilled", async () => {
  const sut = new Iterator()
  const maxIterations = 5
  let currentIteration = 0
  const action = async () => {
    currentIteration++;
    return "hello world";
  };
  const breakCondition = (anyResult: string) => currentIteration == 3
  const result = await sut.iterate(maxIterations, action, breakCondition)
  assertEquals(currentIteration, 3)
});


// tests/standalone-generation.test.ts
import { assertEquals, assertRejects } from "https://deno.land/std/assert/mod.ts";
import { Coordinator, Client, Runner, RunResult, Message } from "../coordinator.ts";

Deno.test("generateCodeFromSpecs delivers error on client error", async () => {
  const client = new ClientStub(anyError())
  const sut = makeSUT({client})
  await assertRejects(()=>sut.generateCodeFromSpecs("any system prompt",anySpecs()), Error, "any error")
});

Deno.test("generateCodeFromSpecs delivers code on client succes", async () => {
  const client = new ClientStub("any code")
  const sut = makeSUT({client})
  const result = await sut.generateCodeFromSpecs("any system prompt", anySpecs())
  assertEquals(result.generatedCode, "any code")
})

Deno.test("generateCodeFromSpecs delivers error on runner error", async () => {
  const runner = new RunnerStub(anyError())
  const sut = makeSUT({runner})
  await assertRejects(()=>sut.generateCodeFromSpecs("any system prompt", anySpecs()), Error, "any error")
})

Deno.test("generateCodeFromSpecs delivers generated code on runner success", async () => {
  const runner = new RunnerStub(anySuccessRunnerResult)
  const sut = makeSUT({runner})
  const result = await sut.generateCodeFromSpecs("any system prompt", anySpecs())
  assertEquals(result.generatedCode, "any code")
})

Deno.test("generateCodeFromSpecs sends correct messages to client", async () => {
  class ClientSpy implements Client {
    received: Message[] = []
    constructor() {}
    async send(messages: Message[]): Promise<string> {
      this.received = messages
      return "any generated code"
    }
  }

  const client = new ClientSpy()
  const sut = makeSUT({client})
  await sut.generateCodeFromSpecs("any system prompt", anySpecs())
  const systemPromptMessage: Message = {
    role: "system",
    content: "any system prompt"
  }
  const userMessage: Message = { role: "user", content: anySpecs() }
  assertEquals(client.received, [systemPromptMessage, userMessage])
})

Deno.test("generateAndEvaluateCode sends concatenated code to runner", async () => {
  class RunnerSpy implements Runner {
    received: string[] = []
    constructor() { }
    run(code: string): RunResult {
      this.received.push(code)
      return {isValid: true}
    }
  }

  const client = new ClientStub("any generated code")
  const runner = new RunnerSpy()
  const sut = makeSUT({ client, runner })
  await sut.generateCodeFromSpecs("any system prompt", anySpecs())
  assertEquals(runner.received, ["any specs\nany generated code"])
});

Deno.test("generateAndEvaluatedCode delivers expected result on client and runner success", async () => {
  const client = new ClientStub("any code")
  const runner = new RunnerStub({isValid: false})
  const sut = makeSUT({client, runner})
  const result = await sut.generateCodeFromSpecs("any system prompt", anySpecs())
  const expectedResult: Coordinator.Result = {
    generatedCode: "any code",
    isValid: false
  }
  assertEquals(result, expectedResult)
})

const anySuccessRunnerResult = { isValid: true}
const anyError = () => Error("any error")
const anySpecs = () => "any specs"

// Stubs

class ClientStub implements Client {
  constructor(private result: string | Error) {}
  async send(): Promise<string> {
    if (this.result instanceof Error) {
      throw this.result
    }
    return this.result
  }
}

class RunnerStub implements Runner {
  constructor(private result: RunResult | Error) {}
  run(code: string): RunResult {
    if (this.result instanceof Error) {
      throw this.result
    }
    return this.result
  }
}

const anySuccesfulClient = new ClientStub("any code")
const anySuccesfulRunner = new RunnerStub(anySuccessRunnerResult)

import { Iterator } from "../iterator.ts";
const anyIterator = new Iterator()
const makeSUT = ({ client = anySuccesfulClient, runner = anySuccesfulRunner }: {
  client?: Client,
  runner?: Runner
}): Coordinator => new Coordinator(client, runner, anyIterator);


// tests/viewModel.test.ts
import { assert, assertEquals } from "https://deno.land/std/assert/mod.ts";
import { Coordinator, Client, Runner, RunResult, Message } from "../coordinator.ts";
import {  makeReactiveViewModel } from "../viewModel.ts";

const maxIterations = 5

Deno.test("ViewModel state updates during code generation", async () => {
  const client = new ClientStub("gencode")
  const alwaysFailingRunner = new RunnerStub({ isValid: false });
  const viewModel = makeReactiveViewModel(client, alwaysFailingRunner, maxIterations)
  await viewModel.run()

  assertEquals(viewModel.currentIteration, 5)
  assertEquals(viewModel.statuses, ['failure', 'failure', 'failure', 'failure', 'failure'])
  assertEquals(viewModel.generatedCodes, ['gencode', 'gencode', 'gencode', 'gencode', 'gencode'])
});

Deno.test("ViewModel delivers failure on client failure", async () => {

  const anyError = new Error("any error")
  const throwingErrorClient = new ClientStub(anyError)
  const anyRunner = new RunnerStub({ isValid: true })
  const viewModel = makeReactiveViewModel(throwingErrorClient, anyRunner, maxIterations)
  await viewModel.run()

  assertEquals(viewModel.status, 'failure', `Expected status to be failure, but got ${viewModel.status} instead`)
})

// Stubs
class RunnerStub implements Runner {
  constructor(private result: RunResult | Error) {}
  run(code: string): RunResult {
    if (this.result instanceof Error) {
      throw this.result
    }
    return this.result
  }
}

class ClientStub implements Client {
constructor(private result: string | Error) {}
 async send(messages: Message[]): Promise<string> {
   if (this.result instanceof Error) {
     throw this.result
   }
   return this.result
 }
}


// viewModel.ts
import { Coordinator, Client, Runner, RunResult, Message } from "./coordinator.ts";
import { Iterator } from "./iterator.ts";

export type Status = "success" | "failure";

interface AppState {
  isRunning: boolean;
  generatedCodes: string[],
  currentIteration: number,
  statuses: Status[],
  specification: string,
  maxIterations: number,
  systemPrompt: string,
}

export interface ViewModel extends AppState {
  run: () => Promise<void>;
  status?: Status;
  generatedCode?: string;
}

class ObservableIterator extends Iterator {
  iterator: Iterator
  onIterationChange?: (iteration: number) => void
  onStatusChange?: (status: Status) => void
  onGeneratedCode?: (code: string) => void
  constructor(iterator: Iterator) { super(); this.iterator = iterator }

  override  async iterate<T>(nTimes: number, action: () => Promise<T>, until: (value: T) => boolean): Promise<T> {
    var iterationCount = 0
    const newAction = async () => {
      iterationCount++

      const result = await action()
      const mapped = result as Coordinator.Result
      this.onStatusChange?.(mapped.isValid ? 'success' : 'failure')
      this.onIterationChange?.(iterationCount)
      this.onGeneratedCode?.(mapped.generatedCode)
      return result
    }
    return await super.iterate(nTimes, newAction, until)
  }
}

export function makeReactiveViewModel(client: Client, runner: Runner, maxIterations: number): ViewModel {
  const baseIterator = new Iterator()
  const observedIterator = new ObservableIterator(baseIterator);
  const coordinator = new Coordinator(client, runner, observedIterator);

  const initialState: AppState = {
    isRunning: false,
    generatedCodes: [],
    currentIteration: 0,
    statuses: [],
    specification: initSpecs(),
    maxIterations: maxIterations,
    systemPrompt: defaultSystemPrompt(),
  }
  const vm: ViewModel = {
    ...initialState,
    run: async function () {
      observedIterator.onIterationChange = (i) => this.currentIteration = i
      observedIterator.onStatusChange = (s) => this.statuses.push(s)
      observedIterator.onGeneratedCode = (c) => this.generatedCodes.push(c)
      this.generatedCodes.splice(0);
      this.statuses.splice(0);
      this.currentIteration = 0;
      this.isRunning = true;
      try {
        await coordinator.generate(this.systemPrompt, this.specification, this.maxIterations);
      } catch {
        this.statuses.push('failure');
      }
      this.isRunning = false;
    },

    get status(): Status | undefined {
      return this.statuses[this.statuses.length - 1];
    },
    get generatedCode(): string | undefined {
      return this.generatedCodes[this.generatedCodes.length - 1];
    }
  };

  return vm;
}

const defaultSystemPrompt = () => `
  Imagine that you are a programmer and the user's responses are feedback from compiling your code in your development environment. Your responses are the code you write, and the user's responses represent the feedback, including any errors.

  Implement the SUT's code in JavaScript based on the provided specs (unit tests).

  Follow these strict guidelines:

  1. Provide ONLY runnable JavaScript code. No explanations, comments, or formatting (no code blocks, markdown, symbols, or text).
  2. DO NOT include unit tests or any test-related code.
  3. DO NOT redefine any global functions or helpers (such as assertEqual) that may already be provided by the environment.
  4. Only implement the code required to make the current test pass.
  5. Avoid including unnecessary wrappers, main functions, or scaffolding — only the essential implementation.

  If your code fails to compile, the user will provide the error output for you to make adjustments.
  `

const initSpecs = () => `
function testAdder() {
  const sut = new Adder(1, 2);
  assertEqual(sut.result, 3);
}

testAdder();`;

