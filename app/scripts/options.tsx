import { Fragment, h, render } from "preact";
import { FC } from "preact/compat";
import { useState, useEffect, useRef } from "preact/hooks";
import "bootstrap/dist/css/bootstrap.css";
import "bootstrap/dist/js/bootstrap.js";
import * as _ from "underscore";

import "../styles/options.scss";
//@ts-ignore
import * as hapt from "./libs/hapt.coffee";

const CONFIG_DESCRIPTIONS = [
  { name: "symbols", description: "Hint characters" },
];

const BINDING_DESCRIPTIONS = [
  { name: "enterHah", description: "Enter HaH mode" },
  { name: "enterHahBg", description: "Enter HaH mode (new tabs)" },
  { name: "quitHah", description: "Quit HaH mode" },
  { name: "toggleAbility", description: "Disable entering HaH mode" },
];

const MODIFIERS = ["Shift", "Ctrl", "Alt", "Command", "Meta"];

interface Config {
  description: string;
  name: string;
  val: any;
}

interface Binding {
  description: string;
  name: string;
  val: string[][];
}

interface Settings {
  configs: Config[];
  bindings: Binding[];
}

const Options: FC = () => {
  const [configs, setConfigs] = useState<Config[]>([]);
  const [bindings, setBindings] = useState<Binding[]>([]);

  const editingRef = useRef<{
    name: string;
    shortcut: string[];
    index: number;
  }>();
  const [_isEditing, _setIsEditing] = useState(false);
  const setEditing = (v: typeof editingRef.current) => {
    editingRef.current = v ?? undefined;
    const editing = editingRef.current;

    _setIsEditing(editing != null);
    if (editing != null && editing.shortcut.length > 0) {
      setBindings((prev) =>
        prev.map((binding) =>
          binding.name !== editing.name
            ? binding
            : {
                ...binding,
                val: binding.val.map((shortcut, i) =>
                  i !== editing.index ? shortcut : editing.shortcut
                ),
              }
        )
      );
    }
  };

  useEffect(() => {
    if (_isEditing || configs.length == 0 || bindings.length == 0) {
      return;
    }

    const convertIntoObject = (options: Config[] | Binding[]) => {
      const obj: any = {};
      options.forEach((option) => {
        obj[option.name] = option.val;
      });
      return obj;
    };

    chrome.runtime.sendMessage({
      type: "setSettings",
      settings: {
        ...convertIntoObject(configs),
        bindings: convertIntoObject(bindings),
      } as Settings,
    });
  }, [_isEditing, configs, bindings]);

  useEffect(() => {
    (async () => {
      const settings = await chrome.runtime.sendMessage({
        type: "getSettings",
      });

      const convertIntoArray = (
        options: any,
        descriptions: { description: string; name: string }[]
      ) =>
        descriptions.map((description) => ({
          description: description.description,
          name: description.name,
          val: options[description.name],
        }));

      setConfigs(
        convertIntoArray(_.omit(settings, "bindings"), CONFIG_DESCRIPTIONS)
      );
      setBindings(convertIntoArray(settings.bindings, BINDING_DESCRIPTIONS));
    })();
  }, []);

  const listenerRef = useRef<any>();

  const listen = () =>
    (listenerRef.current = hapt.listen(
      (keys: string[]) => {
        const editing = editingRef.current;
        setEditing({
          ...editing,
          shortcut: keys,
        });
        if (!MODIFIERS.includes(keys.slice(-1)[0])) {
          finishEditing();
        }
        return false;
      },
      window,
      true,
      ["body", "html", "button", "a"]
    ));

  const finishEditing = () => {
    listenerRef.current?.stop();
    if (editingRef.current == null) {
      return;
    }

    const { name, index } = editingRef.current;
    setBindings((prev) => {
      const binding = prev.find((b) => b.name === name);
      if (
        binding.val[index].every((s) => MODIFIERS.includes(s)) ||
        _.range(binding.val.length).some(
          (i) => i !== index && _.isEqual(binding.val[i], binding.val[index])
        )
      ) {
        return prev.map((b) =>
          b.name !== name ? b : { ...b, val: binding.val.toSpliced(index, 1) }
        );
      }
      return prev;
    });
    setEditing(null);
  };

  const clickShortcut = (
    event: MouseEvent,
    bindingIndex: number,
    index: number
  ) => {
    const binding = bindings[bindingIndex];
    const editing = editingRef.current;
    finishEditing();
    if (editing?.name === binding.name && editing?.index === index) {
      return;
    }    
    setEditing({
      name: binding.name,
      shortcut: binding.val[index],
      index,
    });
    listen();
  };

  const clickRemove = (
    event: MouseEvent,
    bindingIndex: number,
    index: number
  ) => {
    setBindings((prev) => {
      return prev.map((b, i) =>
        i !== bindingIndex
          ? b
          : {
              ...b,
              val: [
                ...b.val.toSpliced(index),
                [],
                ...b.val.toSpliced(0, index + 1),
              ],
            }
      );
    });
    finishEditing();
  };

  const clickAddition = (event: MouseEvent, bindingIndex: number) => {
    finishEditing();
    setBindings((prev) => {
      const binding = prev[bindingIndex];
      setEditing({
        name: binding.name,
        shortcut: [],
        index: binding.val.length,
      });
      return prev.map((b, i) =>
        i !== bindingIndex ? b : { ...b, val: [...b.val, []] }
      );
    });
    listen();
  };

  return (
    <div className="container">
      <div className="page-header">
        <h1>
          <small>Moly</small>HaH
        </h1>
      </div>
      <div>
        <h3>Configuration</h3>
        <table className="table">
          <tbody>
            {configs.map((config) => (
              <tr key={config.name} className="row">
                <td className="col-md-3">{config.description}</td>
                <td>
                  <input
                    type="text"
                    value={config.val}
                    onInput={(e) => {
                      setConfigs(
                        configs.map((c) =>
                          c.name === config.name
                            ? { ...c, val: e.currentTarget.value }
                            : c
                        )
                      );
                    }}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div>
        <h3>Bindings</h3>
        <table className="table">
          <tbody>
            {bindings.map((binding, bindingIndex) => (
              <tr key={binding.name} className="row">
                <td className="col-md-3">{binding.description}</td>
                <td>
                  {binding.val.map((shortcut, index) => (
                    <Fragment key={index}>
                      <button
                        className={`btn col-md-2 ${
                          editingRef.current &&
                          editingRef.current.name === binding.name &&
                          editingRef.current.index === index
                            ? "editing disabled btn-primary"
                            : ""
                        }`}
                        onClick={(event) =>
                          clickShortcut(event, bindingIndex, index)
                        }
                      >
                        {shortcut.length > 0 ? shortcut.join(" ") : "\u00A0"}
                      </button>
                      {editingRef.current &&
                        editingRef.current.name === binding.name &&
                        editingRef.current.index === index && (
                          <button
                            className="btn col-md-1 btn-primary"
                            onClick={(event) =>
                              clickRemove(event, bindingIndex, index)
                            }
                          >
                            {/* workaround for parcel that ruins glyphicon-remove */}
                            <span className="glyphicon" aria-hidden="true">
                              {"\u{e014}"}
                            </span>
                          </button>
                        )}
                    </Fragment>
                  ))}
                  <button
                    className="btn col-md-1"
                    onClick={(event) => clickAddition(event, bindingIndex)}
                  >
                    {/* workaround for parcel that ruins glyphicon-plus-sign */}
                    <span className="glyphicon" aria-hidden="true">
                      {"\u{e081}"}
                    </span>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

render(<Options />, document.getElementById("root"));
